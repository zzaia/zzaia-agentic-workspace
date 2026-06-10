FROM mcr.microsoft.com/playwright/mcp:v0.0.75

USER root
RUN npm install -g @opentelemetry/auto-instrumentations-node@0.76.0
USER node

ENTRYPOINT ["node", "/app/cli.js"]
CMD ["--headless", "--browser", "chromium", "--port", "3006", "--host", "0.0.0.0", "--allowed-hosts", "*"]
