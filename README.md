# Shop on Rails API

## Table of Contents
- [Functionality Overview](#functionality-overview)
- [Prerequisites](#prerequisites)
- [Installation and Setup](#installation-and-setup)
- [Troubleshooting](#troubleshooting)
- [Directory Structure](#directory-structure)
- [Testing](#testing)
- [Useful Commands](#useful-commands)
- [Useful Addresses](#useful-addresses)
- [Actions](#actions)
- [License](#license)

---

## Functionality Overview
The **Shop on Rails API** is a central API service responsible for managing users, authorization, products, orders, and payments within the application ecosystem. Its primary goal is to provide a robust and secure foundation for all operations.

Key features include:
- **User Lifecycle Management**: Full support for registration, account activation, verification, and account deletion processes.
- **Advanced Authorization**:
    - Generation and validation of secure JWTs.
    - Support for two-factor authentication (2FA).
    - Password reset mechanism (xddd).
- **Product and Order Management**: Full lifecycle for products, shopping carts, orders, and payments.
- **Access Control (Roles)**: A role-based system (e.g., `admin`, `moderator`) that allows for fine-grained control over access to different parts of the system.
- **N8n webhooks**: Allowing to integrate easily with outer dependencies.
- **Activity Tracking**: Recording of key actions performed by users.

---

## Prerequisites
- **Operating System**: Linux, macOS, or Windows (with WSL2).
- **Ruby**: Version 3.2.2 or newer.
- **Rails**: Version 7.1 or newer.
- **Bundler**: For managing Ruby dependencies.
- **PostgreSQL**: As the primary database.
- **Redis**: For caching and background jobs.
- **Docker Engine**: Version 20.10.0 or newer.
- **Docker Compose**: For orchestrating containers in the development environment.

---

## Installation and Setup
1.  Clone the repository:
    ```bash
    git clone <your-repository-address>
    cd <project-name>
    ```
2.  Configure environment variables. Copy the example `.env` file and customize it if needed.
    ```bash
    cp .env.example .env
    ```
3.  Build the Docker images:
    ```bash
    docker-compose build
    ```
4.  Start the containers in the background:
    ```bash
    docker-compose up -d
    ```
5.  Prepare the database (create it and run migrations):
    ```bash
    docker-compose exec app bin/rails db:create db:migrate
    ```

Your application is now running and available at `http://localhost:3000`.

---

## Troubleshooting
- **Database Connection Errors**: Ensure the `db` and `redis` containers are running (`docker-compose ps`). Check your `config/database.yml` configuration – the database host should be `db`.
- **Docker Not Running**: Start the Docker Desktop application or Docker daemon before running `docker-compose` commands.
- **File Permission Issues**: If you encounter `Permission denied` errors, ensure your `docker-compose.yml` is configured to run the container with your user ID (`user: "${UID}:${GID}"`).

---

## Directory Structure
```
.
├── app
│   ├── controllers
│   │   └── api/v1
│   ├── models
│   ├── views
│   │   └── api/v1
│   └── services
├── config
│   ├── initializers
│   └── routes.rb
├── db
│   └── migrate
├── lib
│   └── tasks
├── spec
│   ├── factories
│   ├── requests
│   └── swagger_helper.rb
├── swagger
│   └── v1
│       └── swagger.yaml
├── Dockerfile
└── docker-compose.yml
```
rest of the project folder is created with the rails pattern obviously
---

## Testing
This project uses RSpec for testing. Tests are a key part of ensuring the API's quality and stability.

- **Running all tests**
   ```bash
   docker-compose exec app bundle exec rspec
   ```

- **Running unit tests (e.g., models)**
   ```bash
   docker-compose exec app bundle exec rspec spec/models
   ```

- **Running request tests (API)**
   ```bash
   docker-compose exec app bundle exec rspec spec/requests
   ```
The request specs in the `spec/requests` directory also serve as the definitions for the Swagger (Rswag) documentation.

---

## Useful Commands

- **Generating keys for JWT (if needed)**
   Generate your private key:
   ```bash
   openssl genpkey -algorithm ED25519 -out private_key.pem
   ```
   Then, extract the public key from it:
   ```bash
   openssl pkey -in private_key.pem -pubout -out public_key.pem
   ```

- **Generating Swagger documentation**
   ```bash
   docker-compose exec app bin/rails rswag:specs:swaggerize
   ```

- **Generating migrations and models**
   ```bash
   docker-compose exec app bin/rails generate model MyModelName field:type
   docker-compose exec app bin/rails db:migrate
   ```

- **Running the Rails console**
   ```bash
   docker-compose exec app bin/rails c
   ```

---

## Useful Addresses

- **Rails Application**
   `http://localhost:3000`

- **Swagger UI Documentation**
   `http://localhost:3000/api-docs`

---

## Actions and updates
![Alt](https://repobeats.axiom.co/api/embed/0ccd32c70b973168f94e36384a64155cb9867f07.svg "Repobeats analytics image")
---

## License
© 2025 Robert Moń, Kacper Majda All Rights Reserved.
Use this stuff whenever you want for non-commercial purposes.
