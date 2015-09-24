// Defining 2 SQL collections. The additional paramater is the postgres connection string which will only run on the server
tasks = new SQL.Collection('tasks');
username = new SQL.Collection('username');
/***FRONTEND***/
if (Meteor.isClient) {
  var newUser = 'all';
  var taskTable = {
    id: ['$number'],
    text: ['$string', '$notnull'],
    checked: ['$bool'],
    usernameid: ['$number']
  };
  tasks.createTable(taskTable);

  var usersTable = {
    id: ['$number'],
    name: ['$string', '$notnull']
  };
  username.createTable(usersTable);

  Template.body.helpers({
    usernames: function () {
      return username.select().fetch();
    },
    tasks: function () {
      if (newUser === 'all'){
          return tasks.select('tasks.id', 'tasks.text', 'tasks.checked', 'tasks.created_at', 'username.name')
            .join(['OUTER JOIN'], ['usernameid'], [['username', ['id']]])
            .fetch();
      }
      else {
        return tasks.select('tasks.id', 'tasks.text', 'tasks.checked', 'tasks.created_at', 'username.name')
          .join(['OUTER JOIN'], ['usernameid'], [['username', ['id']]])
          .where("name = ?", newUser)
          .fetch();
      }
    }
  });

  Template.body.events({
    "submit .new-task": function (event) {
      if (event.target.category.value){
        var user = username.select()
                     .where("name = ?", event.target.category.value)
                     .fetch();
        user = user[0].id;
        var text = event.target.text.value;
       Meteor.call('new-task', {
          text:text,
          checked:false,
          usernameid: user
        }, function(error,response) {
        event.target.text.value = "";
       });
      } else{
        alert("please add a user first");
      }
      return false;
    },
    "submit .new-user": function (event) {
      var text = event.target.text.value;
       Meteor.call('new-user', {name: text}, function(error,response) {
        event.target.text.value = "";
       });
      return false;
    },
    "click .toggle-checked": function () {
       this.checked =! this.checked;
       Meteor.call('toggle-check-task', this);
       //todo: change not sent from db trigger on publish select with join, manual client update data
       tasks.update({"checked": this.checked})
       .where("id = ?", this.id).save();
       return false;
    },
    "click .delete": function () {
       Meteor.call('remove-task', this);
       return false;
    },
    "change .catselect": function(event){
      newUser = event.target.value;
      tasks.reactiveData.changed();
    }
  });
}
/***BACKEND***/
if (Meteor.isServer) {
  Meteor.startup(function(){
    tasks.createTable(
      {text: ['$string'], checked: ["$bool", {'$default': false}], usernameid: ['$string']},
      []
    );
    username.createTable(
      {name: ['$string', '$unique']},
      [{'name':'all'}]
    );

    Meteor.methods({
      'new-task': function (params) {
        return tasks.insert(params).save();
      },
      'new-user': function (params) {
        return username.insert(params).save();
      },
      'toggle-check-task': function (params) {
        return tasks.update({"checked": (params.checked)?'1':'0'})
        .where("id = ?", params.id)
        .save();
      },
      'remove-task': function (params) {
        return tasks.remove().where("id = ?", params.id).save();
      },
    });
  });

  tasks.publish('tasks', function(){
    return tasks.select('tasks.id as id', 'tasks.text', 'tasks.checked', 'tasks.created_at', 'username.id as usernameid', 'username.name')
       .join(['INNER JOIN'], ["usernameid"], [["username", 'id']])
       .order('created_at DESC')
       .limit(100);
  });

  username.publish('username', function(){
    return username.select('id', 'name')
                   .order('created_at DESC')
                   .limit(100);
  });
}
