FROM mcr.microsoft.com/playwright/mcp:latest

ENTRYPOINT ["node", "/app/cli.js"]
CMD ["--headless", "--browser", "chromium", "--port", "3006", "--host", "0.0.0.0", "--allowed-hosts", "*"]
