/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // remove field
  collection.fields.removeById("text2290771050")

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // add field
  collection.fields.addAt(8, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text2290771050",
    "max": 0,
    "min": 0,
    "name": "processed_by",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
})
