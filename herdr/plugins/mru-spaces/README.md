# MRU Spaces

Keeps Herdr's Spaces sidebar ordered by the most recent agent transition into
`working`. Viewing or focusing a Space does not change its position. Linked
worktree groups move as one block with their parent first.

This changes Herdr's persisted workspace order; it is not a display-only sort.
Shell commands, editors, and input sent while an agent is already working do not
count as new usage.

## Link locally

```sh
herdr plugin link ~/dotfiles/herdr/plugins/mru-spaces
```

## Test

```sh
python3 -m unittest discover -s ~/dotfiles/herdr/plugins/mru-spaces -p 'test_*.py'
```
