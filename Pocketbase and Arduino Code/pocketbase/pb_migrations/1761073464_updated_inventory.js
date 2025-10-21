/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id = source_device.owner.id",
    "deleteRule": "@request.auth.id = source_device.owner.id",
    "listRule": "@request.auth.id = source_device.owner.id",
    "updateRule": "@request.auth.id = source_device.owner.id",
    "viewRule": "@request.auth.id = source_device.owner.id"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != \"\"",
    "deleteRule": "@request.auth.id != \"\"",
    "listRule": "@request.auth.id != \"\"",
    "updateRule": "@request.auth.id != \"\"",
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
