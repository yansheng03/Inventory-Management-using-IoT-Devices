/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // remove field
  collection.fields.removeById("number158830993")

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // add field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "number158830993",
    "max": null,
    "min": null,
    "name": "confidence",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
})
