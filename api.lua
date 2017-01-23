-- local crud = require "kong.api.crud_helpers"

-- return {
--   ["/apis/:api_username_or_id/response-cache"] = {
--     before = function(self, dao_factory, helpers)
--       crud.find_api_by_name_or_id(self, dao_factory, helpers)
--       self.params.api_id = self.api.id
--     end,

--     GET = function(self, dao_factory)
--       crud.paginated_set(self, dao_factory.response_cache)
--     end,

--     PUT = function(self, dao_factory)
--       crud.put(self.params, dao_factory.response_cache)
--     end,

--     POST = function(self, dao_factory)
--       crud.post(self.params, dao_factory.response_cache)
--     end
--   },
--   ["/apis/:api_username_or_id/response-cache/:name_or_id"] = {
--     before = function(self, dao_factory, helpers)
--       crud.find_api_by_name_or_id(self, dao_factory, helpers)
--       self.params.api_id = self.api.id
--     end,

--     GET = function(self, dao_factory)
--       crud.paginated_set(self, dao_factory.response_cache)
--     end,

--     PUT = function(self, dao_factory)
--       crud.put(self.params, dao_factory.response_cache)
--     end,

--     POST = function(self, dao_factory)
--       crud.post(self.params, dao_factory.response_cache)
--     end
--   }
-- }