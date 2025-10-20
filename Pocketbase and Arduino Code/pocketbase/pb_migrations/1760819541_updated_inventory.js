/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // add field
  collection.fields.addAt(7, new Field({
    "hidden": false,
    "id": "bool1159652524",
    "name": "in_fridge",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "bool"
  }))

  // add field
  collection.fields.addAt(8, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3452636744",
    "max": 0,
    "min": 0,
    "name": "last_action",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_250649598",
    "hidden": false,
    "id": "relation3809525459",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "last_updated_from",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // update field
  collection.fields.addAt(1, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text521872670",
    "max": 0,
    "min": 0,
    "name": "item_name",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // remove field
  collection.fields.removeById("bool1159652524")

  // remove field
  collection.fields.removeById("text3452636744")

  // remove field
  collection.fields.removeById("relation3809525459")

  // update field
  collection.fields.addAt(1, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text521872670",
    "max": 0,
    "min": 0,
    "name": "item",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
})
