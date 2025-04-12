import requests
import json
import os
from datetime import datetime
import pathlib
import time

# サーバーのベースURL（今回は http://127.0.0.1:2024 に設定）
BASE_URL = "http://127.0.0.1:2024"

# デバッグ用のディレクトリパス
DEBUG_DIR = pathlib.Path("./debug_logs")


def create_thread():
    """
    新しいスレッドを作成する。作成に成功した場合、スレッドIDを返す。
    """
    url = f"{BASE_URL}/threads"
    # シンプルなスレッド作成用のペイロード。必要に応じて他のフィールドを追加可能。
    payload = {"metadata": {"purpose": "conversation"}}
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        thread_data = response.json()
        print("スレッドが作成されました。Thread ID:", thread_data.get("thread_id"))
        return thread_data.get("thread_id")
    except requests.exceptions.RequestException as e:
        print("スレッド作成中にエラーが発生しました:", e)
        return None


def run_in_thread(thread_id, user_input, response_extras=None, save_debug=True):
    """
    指定されたスレッドIDでユーザー入力に対する実行を開始し、レスポンスを取得する。
    RunCreateStateful の仕様に沿って、assistant_id と input をペイロードに含める。

    Args:
        thread_id (str): 対話スレッドのID
        user_input (str): ユーザーの入力テキスト
        response_extras (dict, optional): レスポンスモデルに追加するカスタムフィールド
        save_debug (bool): デバッグ用にレスポンスをJSONファイルに保存するかどうか
    """
    url = f"{BASE_URL}/threads/{thread_id}/runs/wait"
    payload = {
        "assistant_id": "agent",  # デフォルトグラフIDとして "agent" を指定
        "input": {"messages": [{"role": "human", "content": user_input}]},
    }

    # カスタムレスポンスフィールドが指定されている場合は追加
    if response_extras:
        payload["config"] = {"configurable": {"response_model_extras": response_extras}}

    # リクエスト情報をデバッグ用に保存
    debug_info = {"request": {"url": url, "payload": payload}}

    # 開始時間を記録
    start_time = time.time()

    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        result = response.json()

        # 処理時間を計算
        processing_time = time.time() - start_time

        # デバッグ用にレスポンスをJSONファイルに保存
        if save_debug:
            debug_info["response"] = result
            debug_info["processing_time"] = processing_time
            save_response_to_file(user_input, debug_info)

        return result
    except requests.exceptions.RequestException as e:
        error_info = {"error": str(e)}

        # エラー情報もデバッグ用に保存
        if save_debug:
            debug_info["error"] = error_info
            debug_info["processing_time"] = time.time() - start_time
            save_response_to_file(user_input, debug_info)

        return error_info


def save_response_to_file(user_input, debug_data):
    """
    デバッグ情報をJSONファイルに保存する

    Args:
        user_input (str): ユーザーの入力テキスト
        debug_data (dict): デバッグ情報（リクエスト、レスポンスなど）
    """
    # デバッグディレクトリが存在しない場合は作成
    DEBUG_DIR.mkdir(exist_ok=True, parents=True)

    # タイムスタンプを含むファイル名を生成
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    # ユーザー入力の先頭10文字を使用（ファイル名に使えない文字は削除）
    input_prefix = (
        "".join(c for c in user_input[:10] if c.isalnum() or c in " _-")
        .strip()
        .replace(" ", "_")
    )
    filename = f"{timestamp}_{input_prefix}.json"

    # 基本情報を追加
    debug_data["timestamp"] = datetime.now().isoformat()
    debug_data["user_input"] = user_input

    # JSONファイルに保存
    file_path = DEBUG_DIR / filename
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(debug_data, f, ensure_ascii=False, indent=2)

    print(f"デバッグ情報を保存しました: {file_path}")


def extract_response_content(response_data):
    """
    APIレスポンスから実際の返答内容を抽出する

    Args:
        response_data (dict): APIレスポンス

    Returns:
        dict: 抽出された返答内容（見つからない場合は元のレスポンス）
    """
    try:
        # レスポンスの構造に応じて内容を取り出す
        if isinstance(response_data, dict):
            # 現在の構造は "output" -> "messages" -> [...] の最初の要素
            if "output" in response_data and "messages" in response_data["output"]:
                messages = response_data["output"]["messages"]
                if messages and isinstance(messages, list) and len(messages) > 0:
                    message = messages[0]

                    # additional_kwargsからjson_dataを取得
                    if (
                        "additional_kwargs" in message
                        and "json_data" in message["additional_kwargs"]
                    ):
                        return message["additional_kwargs"]["json_data"]

                    # 従来の方法（contentからJSONを抽出）もバックアップとして残す
                    content = message.get("content")
                    if content:
                        # contentがオブジェクトの場合はそのまま返す
                        if isinstance(content, dict):
                            return content
                        # contentが文字列の場合はJSONとしてパースを試みる
                        elif isinstance(content, str):
                            try:
                                return json.loads(content)
                            except json.JSONDecodeError:
                                return {"text": content}

        # 抽出できない場合は元のレスポンスを返す
        return response_data
    except Exception as e:
        print(f"レスポンス内容の抽出中にエラーが発生しました: {e}")
        return response_data


def format_response(response_data):
    """
    レスポンスデータを見やすく整形する

    Args:
        response_data (dict): APIレスポンスデータ

    Returns:
        str: 整形されたレスポンス文字列
    """
    try:
        # エラーがある場合はそのまま表示
        if "error" in response_data:
            return f"エラー: {response_data['error']}"

        # サーバーエラーの場合
        if "__error__" in response_data:
            return f"サーバーエラー: {response_data['__error__']['message']}"

        # レスポンス構造を調査
        if "output" in response_data and "messages" in response_data["output"]:
            messages = response_data["output"]["messages"]
            if messages and isinstance(messages, list) and len(messages) > 0:
                message = messages[0]

                # 会話内容を取得
                content = message.get("content", "")

                # メタデータを取得
                metadata = {}
                if (
                    "additional_kwargs" in message
                    and "json_data" in message["additional_kwargs"]
                ):
                    metadata = message["additional_kwargs"]["json_data"]

                # 感情状態を取得
                emotion = metadata.get("emotion", "normal")

                # フォーマットされた応答を作成
                formatted = f"タフト ({emotion}): {content}"

                # その他のメタデータを表示（emotion以外）
                extra_info = []
                for key, value in metadata.items():
                    if key != "emotion":
                        extra_info.append(f"{key}: {value}")

                if extra_info:
                    formatted += f"\n[{', '.join(extra_info)}]"

                return formatted

        # 上記の構造に一致しない場合はレガシー方式でフォールバック
        content = extract_response_content(response_data)

        # デバッグ情報
        print("抽出されたデータ構造:", type(content))

        # 会話内容と感情を表示（タフトのフォーマットに対応）
        if isinstance(content, dict):
            if "content" in content and "emotion" in content:
                message = content["content"]
                emotion = content["emotion"]
                formatted = f"タフト ({emotion}): {message}"

                # その他の情報（タイムスタンプ、バージョンなど）
                extra_info = []
                for key, value in content.items():
                    if key not in ["content", "emotion"]:
                        extra_info.append(f"{key}: {value}")

                if extra_info:
                    formatted += f"\n[{', '.join(extra_info)}]"

                return formatted
            else:
                # contentとemotionが見つからない場合は単純に表示
                return f"データ: {json.dumps(content, ensure_ascii=False, indent=2)}"

        # 元のメッセージの内容を表示（構造化されていない場合）
        if "output" in response_data and "messages" in response_data["output"]:
            messages = response_data["output"]["messages"]
            if messages and len(messages) > 0:
                simple_msg = messages[0].get("content", "")
                if simple_msg:
                    return f"メッセージ: {simple_msg}"

        # 上記以外の場合はJSONとして整形
        return json.dumps(content, ensure_ascii=False, indent=2)

    except Exception as e:
        print(f"レスポンスの整形中にエラーが発生しました: {e}")
        # エラーが発生した場合は元のデータをそのまま返す
        return str(response_data)


def main():
    print("スレッドを作成して対話を開始します。")
    thread_id = create_thread()
    if thread_id is None:
        print("スレッド作成に失敗したため、対話を開始できません。")
        return

    print("対話型クライアントへようこそ！")
    print(
        "対話を続けるにはメッセージを入力してください。終了するには 'exit' と入力してください。"
    )
    print("デバッグコマンド:")
    print(" - !debug on: デバッグログ保存を有効にする")
    print(" - !debug off: デバッグログ保存を無効にする")
    print(" - !debug list: 保存されたデバッグログファイルを一覧表示")
    print(" - !debug open <ファイル名>: 指定したデバッグログファイルを開く")
    print(" - !debug raw: 生のレスポンスデータを表示するモードを切り替え")

    # カスタムレスポンスフィールドの例
    response_extras = {
        "timestamp": "auto",  # "auto"は特殊値として処理できる
        "version": "1.0",
    }

    # デバッグモードの初期設定
    debug_mode = True
    # 生データ表示モード
    raw_mode = False

    while True:
        user_input = input(">> ").strip()

        # 特別なコマンドの処理
        if user_input.lower() == "exit":
            print("対話を終了します。")
            break
        elif user_input.startswith("!debug"):
            parts = user_input.split()
            if len(parts) > 1:
                debug_cmd = parts[1].lower()
                if debug_cmd == "on":
                    debug_mode = True
                    print("デバッグログの保存を有効にしました。")
                elif debug_cmd == "off":
                    debug_mode = False
                    print("デバッグログの保存を無効にしました。")
                elif debug_cmd == "raw":
                    raw_mode = not raw_mode
                    print(f"生データ表示モード: {'オン' if raw_mode else 'オフ'}")
                elif debug_cmd == "list":
                    if DEBUG_DIR.exists():
                        files = list(DEBUG_DIR.glob("*.json"))
                        if files:
                            print("保存されたデバッグログファイル:")
                            for i, f in enumerate(
                                sorted(
                                    files, key=lambda x: x.stat().st_mtime, reverse=True
                                )
                            ):
                                print(f" {i+1}. {f.name}")
                        else:
                            print("デバッグログファイルはまだありません。")
                    else:
                        print("デバッグログディレクトリがまだ作成されていません。")
                elif debug_cmd == "open" and len(parts) > 2:
                    file_name = parts[2]
                    file_path = DEBUG_DIR / file_name
                    if file_path.exists():
                        try:
                            with open(file_path, "r", encoding="utf-8") as f:
                                debug_contents = json.load(f)
                                print(
                                    json.dumps(
                                        debug_contents, ensure_ascii=False, indent=2
                                    )
                                )
                        except Exception as e:
                            print(f"ファイルを開く際にエラーが発生しました: {e}")
                    else:
                        print(f"ファイル '{file_name}' は存在しません。")
            continue

        # 通常の対話処理
        result = run_in_thread(
            thread_id, user_input, response_extras, save_debug=debug_mode
        )

        # 結果を表示
        if "error" in result:
            print("エラー:", result["error"])
        else:
            if raw_mode:
                # 生データを表示
                print("生データ:", json.dumps(result, ensure_ascii=False, indent=2))
            else:
                # 整形されたレスポンスを表示
                print(format_response(result))


if __name__ == "__main__":
    main()
