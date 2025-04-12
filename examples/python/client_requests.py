import requests

# サーバーのベースURL（今回は http://127.0.0.1:2024 に設定）
BASE_URL = "http://127.0.0.1:2024"


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


def run_in_thread(thread_id, user_input):
    """
    指定されたスレッドIDでユーザー入力に対する実行を開始し、レスポンスを取得する。
    RunCreateStateful の仕様に沿って、assistant_id と input をペイロードに含める。
    """
    url = f"{BASE_URL}/threads/{thread_id}/runs/wait"
    payload = {
        "assistant_id": "agent",  # デフォルトグラフIDとして "agent" を指定
        "input": {"messages": [{"role": "human", "content": user_input}]},
    }
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        result = response.json()
        return result
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


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

    while True:
        user_input = input(">> ").strip()
        if user_input.lower() == "exit":
            print("対話を終了します。")
            break
        result = run_in_thread(thread_id, user_input)
        # エラーが発生している場合はエラーメッセージを表示
        if "error" in result:
            print("エラー:", result["error"])
        else:
            # 出力形式はサーバーの実装に依存します。ここでは result をそのまま表示しています。
            print("回答:", result)


if __name__ == "__main__":
    main()
