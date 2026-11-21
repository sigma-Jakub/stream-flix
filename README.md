# StreamFlix

StreamFlix is a streaming service system for films and series. It consists of a
REST API (Java, Spring Boot), a MariaDB database and a web application
(HTML, CSS, JavaScript). The project is containerized using Docker.

## Requirements

- Docker Desktop, installed and running
- Git, to clone the repository (or download it as a ZIP)

Java, Maven and MariaDB do not need to be installed. Every component is built
and started inside its own container.

## Start

From the root of the repository:

```powershell
docker compose up -d --build
```

The first start might take some time, because images and dependencies are
downloaded. Run the same command again after pulling new code, so the images
are rebuilt with the latest version.

When everything is running, open http://localhost:3000

Check the status of the containers with:

```powershell
docker compose ps
```

## Stop

```powershell
docker compose down
```

This stops and removes the containers. The database data is kept.

## Reset the database

```powershell
docker compose down -v
```

This also deletes the database volume, so all data is removed. On the next
start, the scripts in `database/init` run again and the database is filled
with the original test data.

Use this after the SQL scripts in `database/init` have changed, or to get the
original test data back.

## Ports

| Service  | Address               | Variable   |
|----------|-----------------------|------------|
| Web app  | http://localhost:3000 | `WEB_PORT` |
| API      | http://localhost:8080 | `API_PORT` |
| Database | localhost:3306        | `DB_PORT`  |

If a port is already in use, set another one in a `.env` file in the
repository root, for example `API_PORT=8081`.

## Connecting to the database

We recommend the Database tool window in IntelliJ IDEA Ultimate, which has
DataGrip built in (free with a JetBrains student licence). Any other database
client that supports MariaDB works as well.

| Field    | Value      |
|----------|------------|
| Type     | MariaDB    |
| Host     | localhost  |
| Port     | 3306 (or the `DB_PORT` you set) |
| Database | streamflix |
| User     | root       |
| Password | root       |

TODO: add the accounts for the internal roles (junior, mid-level, senior).

## Test accounts

TODO: add the test accounts for the web application (account holder and
content manager), once authentication is implemented.

## Coverage report

TODO: add how to run the tests and open the JaCoCo report
(`api/target/site/jacoco/index.html`).
