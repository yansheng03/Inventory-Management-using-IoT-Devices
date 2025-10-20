/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "createRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // update collection data
  unmarshal({
    "createRule": null,
    "listRule": "@request.auth.id != \"\"",
    "updateRule": null,
    "viewRule": "@request.auth.id != \"\""
  }, collection)

  return app.save(collection)
})
