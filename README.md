# Tuft Backend

## 概要
Tuftバックエンドは、LangGraphを活用したReactエージェントを実装したAIバックエンドサービスです。自然言語処理と推論能力を組み合わせて、高度なタスク実行を可能にします。

## 主な機能
- **Reactエージェントアーキテクチャ**: 推論と行動を組み合わせた効率的なエージェント設計
- **LangGraphフレームワーク**: 複雑なAIワークフローをグラフとして管理
- **APIクライアント例**: 異なる接続方法を示す実装例

## プロジェクト構成
```
tuft_backend/
├── app/                  # メインアプリケーション
│   ├── src/              # ソースコード
│   │   └── react_agent/  # Reactエージェント実装
│   ├── tests/            # テストコード
│   └── ...               # その他の設定ファイル
└── examples/             # クライアント実装例
    ├── client_requests.py  # RESTリクエスト実装
    └── client_sdk.py       # SDK実装
```

## インストール方法
リポジトリをクローンし、依存関係をインストールします：

```bash
git clone https://github.com/yourusername/tuft_backend.git
cd tuft_backend/app
pip install -e .
```

## 使用方法
アプリケーションを起動するには：

```bash
cd app
python -m src.react_agent.graph
```

クライアント例を実行するには：

```bash
cd examples
python client_requests.py
# または
python client_sdk.py
```

## 開発環境
- Python 3.10以上
- LangGraph
- その他の依存関係についてはapp/pyproject.tomlを参照してください

## ライセンス
MITライセンス - 詳細はLICENSEファイルを参照してください。

## コントリビューション
プルリクエストは大歓迎です。大きな変更を行う前には、まずissueで変更内容について議論してください。 