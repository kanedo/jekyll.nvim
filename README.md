# jekyll.nvim

Neovim plugin to create jekyll posts. 

This is a work in progress.

## Installation

### lazy.nvim

```lua
return {
    'kanedo/jekyll.nvim',
    dependencies = { 
        "nvim-lua/plenary.nvim", 
        "nvim-telescope/telescope.nvim",
    },
}
```

## Usage

- Provides command `:JekyllPost` to create a post file in `$(CWD)/_posts/<date>_title.md`
- Provides command `:JekyllNote` to create a note file in `$(CWD)/_notes/<date>_slug.md` 
- Provides command `:JekyllDraft` to create a draft file in `$(CWD)/_drafts/title.md`  
- Provides command `:JekyllPromote` to promote a draft to post.

