# Contributing

## New Release Checklist

- [ ] Update Godot project settings version
- [ ] Update F-Droid metadata with current version
- [ ] Modify RELEASE.md with changes since last version
- [ ] Merge changes to main
- [ ] Push tag (change VERSION):
```bash
export VERSION=v0.0.0
git tag --annotate --cleanup=whitespace --file RELEASE.md $VERSION
git push --tags
```
