{
  description = "codewindow.nvim — Neovim minimap plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      codewindowPlugin = pkgs.vimUtils.buildVimPlugin {
        name = "codewindow.nvim";
        src = self;
      };

      treesitterWithLua = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [ p.lua ]);

      testNvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped (
        pkgs.neovimUtils.makeNeovimConfig {
          plugins = [
            { plugin = pkgs.vimPlugins.mini-nvim; }
            { plugin = treesitterWithLua; }
            { plugin = codewindowPlugin; }
          ];
          extraLuaPackages = ps: [ ps.tiktoken_core ];
        }
      );
    in
    {
      packages.${system}.default = codewindowPlugin;

      checks.${system} = {
        smoke = pkgs.runCommand "codewindow-smoke" {} ''
          export HOME=$(mktemp -d)
          ${testNvim}/bin/nvim --headless -c 'lua vim.cmd("qa!")' 2>&1
          touch $out
        '';

        tests = pkgs.runCommand "codewindow-tests" { nativeBuildInputs = [ pkgs.curl ]; } ''
          export HOME=$(mktemp -d)
          cd ${self}
          ${testNvim}/bin/nvim --headless -u tests/minimal_init.lua \
            -c "lua MiniTest.run({ collect = { find_files = function() \
              return vim.fn.globpath('tests', 'test_*.lua', true, true) \
            end } })"
          touch $out
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ testNvim pkgs.watchexec pkgs.stylua ];
      };
    };
}
