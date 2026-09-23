return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "williamboman/mason.nvim",
    },
    config = function()
      local function executable_from_mise(executable)
        local mise = vim.fn.exepath("mise")

        if mise ~= "" then
          local path = vim.fn.systemlist({ mise, "which", executable })[1]
          if vim.v.shell_error == 0 and path ~= nil and path ~= "" then
            return path
          end
        end

        local path = vim.fn.exepath(executable)
        if path ~= "" then
          return path
        end

        return executable
      end

      local function mason_executable(executable)
        local path = vim.fn.exepath(executable)
        if path ~= "" then
          return path
        end

        local mason_path = vim.fn.stdpath("data") .. "/mason/bin/" .. executable
        if vim.fn.executable(mason_path) == 1 then
          return mason_path
        end

        return executable
      end

      local root_dir = vim.fs.root(0, {
        "pom.xml",
        "mvnw",
        "gradlew",
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
        ".git",
      })

      if root_dir == nil then
        return
      end

      local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
      local root_hash = string.sub(vim.fn.sha256(root_dir), 1, 8)
      local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspaces/" .. project_name .. "-" .. root_hash
      local jdtls = require("jdtls")

      jdtls.start_or_attach({
        cmd = {
          mason_executable("jdtls"),
          "--java-executable",
          executable_from_mise("java"),
          "-data",
          workspace_dir,
        },
        root_dir = root_dir,
        settings = {
          java = {
            maven = {
              downloadSources = true,
            },
            eclipse = {
              downloadSources = true,
            },
            contentProvider = {
              preferred = "fernflower",
            },
            configuration = {
              updateBuildConfiguration = "interactive",
            },
          },
        },
        init_options = {
          extendedClientCapabilities = jdtls.extendedClientCapabilities,
        },
      })
    end,
  },
}
