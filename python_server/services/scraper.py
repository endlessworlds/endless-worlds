import logging
import time
import requests
from bs4 import BeautifulSoup
from ddgs import DDGS
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib3

import os

# DISABLE_SSL_VERIFY=1 works around proxies/AV that intercept HTTPS (local dev only).
_VERIFY = os.getenv("DISABLE_SSL_VERIFY") != "1"
if not _VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger("EndlessWorlds.Scraper")

_HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
_TIMEOUT = 4          # seconds per request (down from 5)
_MAX_WORKERS = 5      # concurrent fetches
_DECOMPOSE_TAGS = ("script", "style", "nav", "footer", "iframe", "header", "aside")


def _fetch_and_clean(link: str) -> tuple[str, str] | None:
    """Fetch a single URL and return (url, cleaned_text) or None on failure."""
    try:
        res = requests.get(link, headers=_HEADERS, timeout=_TIMEOUT, verify=_VERIFY)
        res.raise_for_status()

        soup = BeautifulSoup(res.text, "lxml")
        for tag in _DECOMPOSE_TAGS:
            for el in soup.find_all(tag):
                el.decompose()

        text = soup.get_text(separator=" ", strip=True)
        cleaned = " ".join(text.split())

        if len(cleaned) > 200:
            return link, cleaned
    except Exception:
        pass
    return None


def search_and_scrape(topic: str) -> tuple[str, str]:
    """
    Searches DuckDuckGo for the topic, fetches candidate URLs concurrently,
    and returns the first successfully scraped page.
    Returns a tuple of (target_url, cleaned_text).
    """
    query = f"{topic} tutorial or explanation"
    logger.info("Searching DuckDuckGo — query: \"%s\"", query)
    start = time.time()

    # 1. Search using DuckDuckGo
    # DuckDuckGo often rate-limits servers, so fall through other engines.
    results = []
    for backend in ("auto", "bing", "brave"):
        try:
            with DDGS(verify=_VERIFY) as ddgs:
                results = ddgs.text(query, max_results=10, backend=backend)
            if results:
                break
        except Exception as e:
            logger.warning("Search backend %s failed: %s", backend, e)

    search_time = time.time() - start

    if not results:
        logger.warning("No results returned from DuckDuckGo (took %.2fs)", search_time)
        raise Exception("No results found from DuckDuckGo search.")

    logger.info("DuckDuckGo returned %d results in %.2f seconds", len(results), search_time)

    # 2. Filter to valid HTML links
    links = []
    for r in results:
        href = r.get("href", "")
        if href and not href.lower().endswith((".pdf", ".doc", ".docx")):
            links.append(href)

    if not links:
        logger.warning("No scrapable HTML links found in search results")
        raise Exception("No scrapable HTML links in search results.")

    # 3. Fetch all candidate URLs concurrently — return first success
    logger.info("Scraping %d candidate URLs concurrently (%d workers)...", len(links), _MAX_WORKERS)

    with ThreadPoolExecutor(max_workers=_MAX_WORKERS) as pool:
        future_to_link = {pool.submit(_fetch_and_clean, link): link for link in links}

        for future in as_completed(future_to_link):
            link = future_to_link[future]
            try:
                result = future.result()
                if result:
                    url, text = result
                    elapsed = time.time() - start
                    logger.info("  ✔ Scraped successfully: %s", url)
                    logger.info("    Cleaned text: %d characters — total time: %.2f seconds", len(text), elapsed)
                    # Cancel remaining futures since we have what we need
                    for f in future_to_link:
                        f.cancel()
                    return url, text
                else:
                    logger.info("  ✗ Skipped (too short or failed): %s", link)
            except Exception as e:
                logger.warning("  ✗ Error on %s: %s", link, str(e))

    total_time = time.time() - start
    logger.error("All %d URLs failed after %.2f seconds", len(links), total_time)
    raise Exception("Failed to scrape any suitable HTML results from search.")
