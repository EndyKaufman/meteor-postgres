# PostgreSQL + Meteor (forked from storeness/meteor-postgres)

Adds postgres support to Meteor via `SQL.Collection`, which is similar to
`Mongo.Collection` and provides the same functionality namely livequery, pub/sub, latency compensation and client side cache.

Still I would not recommend using it in production yet as the ORM layer is open for SQL-injections. You can check out [this SQL package blueprint](https://github.com/endykaufman/sql) for a
possible more sophisticated SQL implementation that could support most popular SQL
Databases, Models and Migrations.

### Improvements

- Proper support for IDs (including strings)
- Cleaner code and API
- Support of underscores in table and column names
- Many bug fixes including
  - errors on creating existent tables (convenient for server startup)
  - postgres client event leak
  - alasql column bug
- Working example

### Installation

Run the following from your command line.

```
    meteor add endykaufman:meteor-postgres
```

or add this to your `package.js`

```
    api.use('endykaufman:meteor-postgres');
```

### Usage

To get started you might want to take a look at the [todo-example
code](https://github.com/endykaufman/meteor-postgres/blob/simple-todo.js). You can run
the code by cloning this repo locally and start it by running
`MP_POSTGRES=postgres://{username}:{password}:{url}:{port}/{database_name}
meteor` inside the cloned directory.

### Implementation

We use [Node-Postgres](https://github.com/brianc/node-postgres) on the server and [AlaSQL](https://github.com/agershun/alasql) on the client.
Also thanks to [Meteor-Postgres](http://www.meteorpostgres.com/) as this project
is based on their initial work, but which gets not longer maintained.

### Change on this fork

In the original version of the project was possible sql injection in the Fork is eliminated.
Example of use : https://github.com/EndyKaufman/meteor-postgres/blob/master/simple-todo.js

### License

Released under the MIT license. See the LICENSE file for more info.
