# Branch

> [!NOTE]
> Currently vaporware. In the design phase right now.

Branch is a cross-platform app launcher, based on "tree"s of menus.

Here is an example of a menu tree:

```txt
websites.branch
|
+-> https://search.example.com
|
+-- work/
|   |
|   +-> https://intranet.company.com
|   |
|   +-> https://email.company.com
|
+-- personal/
    |
    +-> https://videos.example.com
    |
    +-> https://pictures.example.com
```

Here, `websites.branch` is a "branch file" that `branch` can read to generate the menu tree.

```sh
branch ./websites.branch
```

This will open the top-level menu, containing `https://search.example.com` (leaf), `work/` (sub-menu), and `personal/` (sub-menu).

Branch files can also assign hot-keys to different menu items (such as `s`, `w`, and `p` respectively).

While in a menu, you can press `/` or `Ctrl-f` to start searching items in the current menu (using fuzzy matching).

There is one menu item that is selected, so that pressing "enter" will launch it. The first item is selected by default (or the closest match if
currently searching), and you can change the selection by using `Up`/`Down` arrow keys or `Ctrl-p`/`Ctrl-n`.

## File format

Branch files are actually Lua scripts that are run by `branch`.

Here is an example script that generates the above tree:

```lua
local Menu = branch.Menu
local App = branch.App

return Menu {
  title = "Websites",

  Site {
    key = "s",

    url = Form {
      format = "https://search.example.com/?q=${query}",
      fields = {
        query = Field {
          label = "Search Query",
          type = "string",
          modify = branch.modify.url_encode,
        },
      },
    },
  },
  Menu {
    title = "Work Sites",
    key = "w",

    Site { url = "https://intranet.company.com" },
    Site { url = "https://email.company.com" }
  },
  Menu {
    title = "Personal Sites",
    key = "p",

    Site { url = "https://videos.example.com" },
    Site { url = "https://pictures.example.com" },
  },
}
```
