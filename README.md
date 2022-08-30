# pkg.sh Package Builder

Helper script to build `PKGBUILD` packages and take `snapper` snapshots
before and after the install.

It will also fetch the latest Arch Linux news feed and offer to upgrade
the system before installing the package.

```bash
pkg.sh gimp-psdark-theme
```

This will change into the `gimp-psdark-theme` directory and run `makepkg`
to create and install the package.

In case the build fails, you can re-use the pre-snapshot taken so an
additional snapshot is not created using the `--pre-snapshot-num`

```bash
pkg.sh -p 203 gimp-psdark-theme
```

If you want to skip the system upgrade (not recommended) then you can use
the `--skip-upgrade` option.

