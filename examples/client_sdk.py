from langgraph_sdk import get_client
import asyncio

client = get_client(url="http://localhost:2024")


async def main():
    async for chunk in client.runs.stream(
        None,  # Threadless run
        "agent",  # Name of assistant. Defined in langgraph.json.
        input={
            "messages": [
                {
                    "role": "human",
                    "content": "What is LangGraph?",
                }
            ],
        },
        stream_mode="updates",
    ):
        print(f"Receiving new event of type: {chunk.event}...")
        print(chunk.data)
        print("\n\n")


# 非同期関数を実行
if __name__ == "__main__":
    asyncio.run(main())
