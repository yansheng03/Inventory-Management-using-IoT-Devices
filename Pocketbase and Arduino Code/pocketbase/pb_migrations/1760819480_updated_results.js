/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // remove field
  collection.fields.removeById("json1761844607")

  // remove field
  collection.fields.removeById("json1902111303")

  // add field
  collection.fields.addAt(3, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text2517842685",
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

  // add field
  collection.fields.addAt(4, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text105650625",
    "max": 0,
    "min": 0,
    "name": "category",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "number2683508278",
    "max": null,
    "min": null,
    "name": "quantity",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // add field
  collection.fields.addAt(6, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text1204587666",
    "max": 0,
    "min": 0,
    "name": "action",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(7, new Field({
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
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_250649598")

  // add field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "json1761844607",
    "maxSize": 0,
    "name": "detections",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "json"
  }))

  // add field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "json1902111303",
    "maxSize": 0,
    "name": "changes_summary",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "json"
  }))

  // remove field
  collection.fields.removeById("text2517842685")

  // remove field
  collection.fields.removeById("text105650625")

  // remove field
  collection.fields.removeById("number2683508278")

  // remove field
  collection.fields.removeById("text1204587666")

  // remove field
  collection.fields.removeById("number158830993")

  // remove field
  collection.fields.removeById("text2290771050")

  return app.save(collection)
})
