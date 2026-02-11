# Backup and Restore Database

> ! Replace "STUDENT with your STUDENTID"

## First Terminal,

Build the custom image (This will take a few minutes)
```sh
docker build -t pg18-512mb --no-cache .
```

Run the container with 512MB RAM and 0.5 CPU Core

```sh
docker run --rm --name pg_30_lab \
    --memory="512m" \
    --memory-swap="512m" \
    --cpus="2.0" \
    --volume "${PWD}/DATA:/var/lib/postgresql/data" \
    --volume "${PWD}/BACKUP:/backup" \
    --security-opt seccomp=unconfined \
    pg18-512mb \
    postgres -D /var/lib/postgresql/data \
    -c max_connections=10 \
    -c work_mem=16MB \
    -c shared_buffers=128MB
```


![A car image](./BACKUP/image.png)

## Second Terminal
### Run psql shell

```sh
docker exec -it pg_30_lab sh
```

### 1) Create the dvdrental database

First, open the Command Prompt on Windows or Terminal on Unix-like systems and connect to the PostgreSQL server using psql tool:

```sh
psql -U postgres 
```

The password for the postgres user is the one you entered during the PostgreSQL installation.

After entering the password correctly, you will be connected to the PostgreSQL server.

The command prompt will look like this:

```psql
postgres=#
```

Second, create a new database called dvdrental using CREATE DATABASE statement:

```sql
CREATE DATABASE dvdrental;
```

PostgreSQL will create a new database called dvdrental.

Third, verify the database creation using the \l command. The \l command will show all databases in the PostgreSQL server:

```sql
\l
```
Output:
```
postgres=# \l
                                                List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |   Access privileges   
-----------+----------+----------+-----------------+---------+-------+--------+-----------+-----------------------
 dvdrental | postgres | UTF8     | libc            | C       | C     |        |           | 
 postgres  | postgres | UTF8     | libc            | C       | C     |        |           | 
 template0 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
(4 rows)
```

Logout from database
```
\q
```

### 2) Backup Database from master

```sh
pg_dump -U STUDENT -h 172.16.2.117 --no-owner  -v -d dvdrental_master > /backup/dvdrental_master_backup.sql
```

Check backup file

```sh
ls -l /backup/
```

Output:
```
/var/lib/postgresql $ ls -l /backup/
total 9584
-rw-r--r--    1 postgres postgres   2766632 Feb 10 14:37 dvdrental_backup.sql
/var/lib/postgresql $ 
```

### 3) Restore database to local

```sh
psql -U postgres -d dvdrental < /backup/dvdrental_master_backup.sql 
```

Check you database

```sh
psql -U postgres -d dvdrental
```

```
\t
```

Output:

```
dvdrental=# \dt
              List of tables
 Schema |     Name      | Type  |  Owner   
--------+---------------+-------+----------
 public | actor         | table | postgres
 public | address       | table | postgres
 public | category      | table | postgres
 public | city          | table | postgres
 public | country       | table | postgres
 public | customer      | table | postgres
 public | film          | table | postgres
 public | film_actor    | table | postgres
 public | film_category | table | postgres
 public | inventory     | table | postgres
 public | language      | table | postgres
 public | payment       | table | postgres
 public | rental        | table | postgres
dvdrental=# 
```

Insert Actor 
```sql
INSERT INTO actor (first_name, last_name) values ('Your Name', 'Your Last Name');
```

Add you as actor in one of film.

```sql
SELECT floor(random() * 1000) + 1 AS film_id;
```

Output:
```
478
```

```sql
INSERT INTO film_actor (actor_id, film_id) VALUES (201, (SELECT floor(random() * 1000) + 1));
```

Get the film that you've acted.

```sql
SELECT actor.*, film.title 
FROM film_actor JOIN film ON film_actor.film_id=film.film_id 
JOIN actor ON film_actor.actor_id=actor.actor_id AND actor.actor_id=201; 
```

Output:


```
 actor_id | first_name | last_name  |        last_update         |   title    
----------+------------+------------+----------------------------+------------
      201 | Yourname   | YourLName  | 2026-02-10 14:52:23.757804 | Jaws Harry
(1 row)
```

Quit database
```
\q
```

### 4) Create my to databases backup

Create simple SQL file backup
```sh
pg_dump -U postgres --no-owner  -v -d dvdrental > /backup/dvdrental_simple.sql
```

Create plain text SQL file backup
```sh
pg_dump --no-owner --format=plain -v -d dvdrental > /backup/dvdrental_plan.sql
```

Create database dump file backup with custom format
```sh
pg_dump -U postgres -d dbname --no-owner  -Fc -v -d dvdrental -f /backup/dvdrental_custom.dump
```


### 5) Restore to my database

Restore with simple sql file.
```sh
psql -U STUDENT -h 172.16.2.117 -d db_STUDENT < /backup/dvdrental_simple.sql
```

Restore with pg_restore with simple sql
```sh
pg_restore -U STUDENT -h 172.16.2.117 --format=plain -v -d db_STUDENT --clean /backup/dvdrental_simple.sql
```

Restore with psql with plan sql
```sh
psql -U STUDENT -h 172.16.2.117 -d db_STUDENT < /backup/dvdrental_plan.sql
```

Restore with pg_dump on custome format
```sh
pg_restore -U STUDENT -h 172.16.2.117 -v -d db_STUDENT --no-owner --clean /backup/dvdrental_custom.dump
```

```sql
psql -U STUDENT -h 172.16.2.117 -d db_STUDENT
```

```sql
SELECT actor.*, film.title 
FROM film_actor JOIN film ON film_actor.film_id=film.film_id 
JOIN actor ON film_actor.actor_id=actor.actor_id AND actor.actor_id=201
```

Your Output:

```

```