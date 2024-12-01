# Support App — Backend

Rails API for a portfolio project inspired by [Mable](https://mable.com.au), a platform that connects people living with disability to independent support workers.

The frontend React app lives in a separate repository: [support_app_frontend](https://github.com/nils-vanderwerf/support_app_frontend).

## What it does

- REST API consumed by the React frontend
- Session-based authentication using Devise and Rails session cookies
- Role-based access control — clients and support workers have different permissions
- Appointment booking between clients and support workers
- CSRF protection for non-GET requests

## Tech stack

- **Ruby on Rails** (API mode with session support)
- **Devise** for authentication
- **SQLite** for development
- **RSpec** for request specs

## Backend concepts practised

- MVC architecture
- RESTful API design
- ActiveRecord associations and database design
- ActiveRecord transactions for data integrity
- Role-based access control with a shared `RoleRegistry` concern
- Session-based authentication (cookies, CSRF)
- Encapsulation and modular design
- RSpec request specs with context blocks

## Running the app

```bash
bundle install
rails db:create db:migrate
rackup -p 9292
```

API runs on [http://localhost:9292](http://localhost:9292).

## Running tests

```bash
bundle exec rspec
```
