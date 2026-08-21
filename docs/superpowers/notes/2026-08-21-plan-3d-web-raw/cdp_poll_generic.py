import json, sys
import urllib.request
import websockets
import asyncio

PORT = int(sys.argv[1])

async def main():
    resp = urllib.request.urlopen(f"http://localhost:{PORT}/json")
    targets = json.loads(resp.read())
    page = None
    for t in targets:
        if t.get("type") == "page":
            page = t
            break
    if page is None:
        print("NO PAGE TARGET FOUND", targets)
        sys.exit(1)
    ws_url = page["webSocketDebuggerUrl"]
    async with websockets.connect(ws_url, max_size=50_000_000) as ws:
        msg_id = 0
        async def evaluate(expr):
            nonlocal msg_id
            msg_id += 1
            await ws.send(json.dumps({
                "id": msg_id, "method": "Runtime.evaluate",
                "params": {"expression": expr, "returnByValue": True}
            }))
            while True:
                raw = await ws.recv()
                data = json.loads(raw)
                if data.get("id") == msg_id:
                    return data

        for attempt in range(150):  # up to ~5 minutes
            result = await evaluate("window.localStorage.getItem('r2Result')")
            value = result.get("result", {}).get("result", {}).get("value")
            if value:
                print("=== RETRIEVED ===")
                print(value)
                return
            await asyncio.sleep(2)
        print("TIMED OUT waiting for r2Result in localStorage")
        sys.exit(2)

asyncio.run(main())
