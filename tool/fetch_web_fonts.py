#!/usr/bin/env python3
"""下载 Web 预览字体到 web/fonts/(不入库;Android 构建不包含该目录)。

本机到 fonts.gstatic.com 不可达时,CanvasKit 渲染中文会在线拉字体分片并无限重试,
导致预览页整片空白。此脚本把 Noto Sans SC 三个字重放到 web/fonts/,
由 lib/web_fonts.dart 在 Web 启动时经 FontLoader 注册。

用法: python tool/fetch_web_fonts.py
"""
import sys
import urllib.request
from pathlib import Path

BASE = "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@Sans2.004/Sans/SubsetOTF/SC"
WEIGHTS = ("Regular", "Medium", "Bold")
OUT_DIR = Path(__file__).resolve().parent.parent / "web" / "fonts"


def main() -> int:
    for weight in WEIGHTS:
        dest = OUT_DIR / f"NotoSansSC-{weight}.otf"
        if dest.exists() and dest.stat().st_size > 1_000_000:
            print(f"已存在,跳过: {dest.name}")
            continue
        url = f"{BASE}/NotoSansSC-{weight}.otf"
        print(f"下载 {url} ...")
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        try:
            urllib.request.urlretrieve(url, dest)
        except OSError as error:
            print(f"失败: {error}", file=sys.stderr)
            return 1
        print(f"完成: {dest} ({dest.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
