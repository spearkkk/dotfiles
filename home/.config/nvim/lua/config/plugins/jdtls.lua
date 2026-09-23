return {
  {
    "mfussenegger/nvim-jdtls",
    ft = { "java" },
    dependencies = {
      "williamboman/mason.nvim",
    },
    config = function()
      local function java_major_version(java)
        local output = vim.fn.systemlist({ java, "-version" })
        if vim.v.shell_error ~= 0 then
          return nil
        end

        local version = table.concat(output, "\n"):match('version "([^"]+)"')
        if version == nil then
          return nil
        end

        if vim.startswith(version, "1.") then
          return tonumber(version:match("^1%.(%d+)"))
        end

        return tonumber(version:match("^(%d+)"))
      end

      local function current_mise_executable(executable)
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

      local function java_for_jdtls()
        local candidates = {
          current_mise_executable("java"),
        }

        vim.list_extend(candidates, vim.fn.glob(vim.fn.expand("~") .. "/.local/share/mise/installs/java/*/bin/java", false, true))

        local best_java = nil
        local best_major = 0

        for _, java in ipairs(candidates) do
          local major = java_major_version(java)
          if major ~= nil and major >= 21 and major > best_major then
            best_java = java
            best_major = major
          end
        end

        return best_java or candidates[1]
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
          java_for_jdtls(),
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
