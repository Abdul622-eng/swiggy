# Use Node.js base image
FROM node:16-slim

# Create and set the working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm install --legacy-peer-deps

# Copy the application source code
COPY . .

# React development server configuration
ENV PORT=2000
ENV HOST=0.0.0.0

# Expose application port
EXPOSE 2000

# Start the React application
CMD ["npm", "start"]
