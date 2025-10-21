/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id = source_device.owner.id",
    "deleteRule": "@request.auth.id = source_device.owner.id",
    "listRule": "@request.auth.id = source_device.owner.id",
    "updateRule": "@request.auth.id = source_device.owner.id",
    "viewRule": "@request.auth.id = source_device.owner.id"
  }, collection)

  // add field
  collection.fields.addAt(3, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_2153001328",
    "hidden": false,
    "id": "relation3218117480",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "source_device",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "relation"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3665455462")

  // update collection data
  unmarshal({
    "createRule": "",
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  // remove field
  collection.fields.removeById("relation3218117480")

  return app.save(collection)
})
