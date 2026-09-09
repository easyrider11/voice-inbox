FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build
RUN mkdir -p .data/audio
ENV NODE_ENV=production PORT=8080
EXPOSE 8080
CMD ["node", "dist/index.js"]
