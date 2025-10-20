/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // remove field
  collection.fields.removeById("text325763347")

  // add field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "json325763347",
    "maxSize": 0,
    "name": "result",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "json"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // add field
  collection.fields.addAt(5, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text325763347",
    "max": 0,
    "min": 0,
    "name": "result",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // remove field
  collection.fields.removeById("json325763347")

  return app.save(collection)
})
