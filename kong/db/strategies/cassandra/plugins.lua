local cassandra = require "cassandra"


local fmt = string.format


local Plugins = {}


local function convert_input(value, typ)
  return (value == nil or value == ngx.null)
         and cassandra.null
         or cassandra[typ](value)
end


local function convert_foreign(row, field, id_field)
  local id = row[id_field]
  if id == nil or id == ngx.null then
    row[field] = ngx.null
  else
    row[field] = { id = id }
  end
  row[id_field] = nil
end


local select_q = "SELECT * FROM plugins " ..
                 " WHERE name = ?" ..
                 " AND route_id = ?" ..
                 " AND service_id = ?" ..
                 " AND consumer_id = ?" ..
                 " AND api_id = ?" ..
                 " ALLOW FILTERING"


function Plugins:select_by_ids(name, route_id, service_id, consumer_id, api_id)
  local connector = self.connector
  local cluster = connector.cluster
  local errors = self.errors

  local res   = {}
  local count = 0

  local args = {
    convert_input(name, "text"),
    convert_input(route_id, "uuid"),
    convert_input(service_id, "uuid"),
    convert_input(consumer_id, "uuid"),
    convert_input(api_id, "uuid"),
  }
  for rows, err in cluster:iterate(select_q, args) do
    if err then
      return nil,
             errors:database_error(fmt("could not fetch plugins: %s", err))
    end

    for i = 1, #rows do
      count = count + 1
      res[count] = rows[i]
    end
  end

  for _, row in ipairs(res) do
    convert_foreign(row, "api", "api_id")
    convert_foreign(row, "route", "route_id")
    convert_foreign(row, "service", "service_id")
    convert_foreign(row, "consumer", "consumer_id")
  end

  return res
end


return Plugins
