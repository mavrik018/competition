"""Smoke test: Selenium Grid (Docker) drives Chrome; pytest writes the report.

Run after `docker compose -f nascon_setup/docker-compose.smoke.yml up -d --wait`:
    python -m pytest nascon_setup/test_smoke.py --html=nascon_setup/report.html --self-contained-html
"""
import time

import pytest
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By

GRID = "http://localhost:4444"


@pytest.fixture(scope="module")
def driver():
    # The Chrome node registers with the hub a few seconds after start-up.
    for _ in range(60):
        if requests.get(f"{GRID}/status", timeout=5).json()["value"]["ready"]:
            break
        time.sleep(1)
    options = webdriver.ChromeOptions()
    browser = webdriver.Remote(command_executor=GRID, options=options)
    yield browser
    browser.quit()


def test_grid_is_ready():
    assert requests.get(f"{GRID}/status", timeout=5).json()["value"]["ready"]


def test_remote_chrome_renders_a_page(driver):
    # A data: URL keeps the test offline (campus Wi-Fi is throttled).
    driver.get("data:text/html,<title>NaSCon</title><h1 id='t'>ready</h1>")
    assert driver.title == "NaSCon"
    assert driver.find_element(By.ID, "t").text == "ready"
