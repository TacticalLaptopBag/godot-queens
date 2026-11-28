# Contributing

## Secrets

In order for GitHub workflows to function, a few secrets must be set in the repository:
`base64 release.keystore -w 0`
| Name | Description |
| ---- | ----------- |
| `ITCH_IO_API_KEY` | itch.io API key generated from the [user profile](https://itch.io/user/settings/api-keys) |
| `SECRET_RELEASE_KEYSTORE_BASE64` | base64-encoded data of the Android keystore. Run `base64 release.keystore -w 0` and copy the resulting text. |
| `SECRET_RELEASE_KEYSTORE_USER` | The username (alias) for the Android keystore |
| `SECRET_RELEASE_KEYSTORE_PASSWORD` | The password for the Android keystore |

## New Release Checklist

- [ ] Update Godot project settings version
- [ ] Update F-Droid metadata with current version
- [ ] Bump Android versionCode in both F-Droid and Android export profiles
- [ ] Modify RELEASE.md with changes since last version
- [ ] Merge changes to main
- [ ] Push tag (change VERSION):
```bash
export VERSION=v0.0.0
git tag --annotate --cleanup=whitespace --file RELEASE.md $VERSION
git push --tags
```
