#!/usr/bin/env python3
"""session-leg.py — 从 pi 会话文件精确提取一棒的内容（ground truth 层）

用法: session-leg.py <session.jsonl> <leg-marker> <out.md>

按 leg 标记（注入任务里的 <!-- leg:ts -->）定位本棒起点（最后一条含标记的
user 消息），将其后所有消息（user/assistant 的文本 + 工具调用占位）写成
markdown。找不到标记则输出全量并在头部标注。精确保真，无终端渲染失真。
"""
import json
import sys


def text_of(msg):
    content = msg.get("content")
    if isinstance(content, str):
        return content
    parts = []
    for block in content or []:
        btype = block.get("type")
        if btype == "text":
            parts.append(block.get("text", ""))
        elif btype == "toolCall":
            args = json.dumps(block.get("arguments", {}), ensure_ascii=False)
            parts.append(f"[tool_call: {block.get('name')} {args[:200]}]")
    return "\n".join(p for p in parts if p)


def main():
    sess_path, marker, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    messages = []
    with open(sess_path, encoding="utf-8") as f:
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") != "message":
                continue
            msg = entry.get("message") or {}
            if msg.get("role") in ("user", "assistant"):
                messages.append(msg)

    start, fell_back = 0, True
    for i in range(len(messages) - 1, -1, -1):
        if messages[i].get("role") == "user" and marker in text_of(messages[i]):
            start, fell_back = i, False
            break

    chunks = []
    if fell_back:
        chunks.append("> ⚠️ 未找到 leg 标记，以下为全量会话内容（非本棒裁剪）\n")
    for msg in messages[start:]:
        text = text_of(msg).strip()
        if text:
            chunks.append(f"## {msg['role']}\n\n{text}")

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(chunks) + "\n")
    print(out_path)


if __name__ == "__main__":
    main()
