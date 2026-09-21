pkgname=said360
pkgver=2.0
pkgrel=1
pkgdesc="Sag kenardan cikan bir daragacinda sallanan şeyh said, imlece tepki veren adam widgeti (KDE Plasma 6)"
arch=('any')
url="https://example.invalid/said360"
license=('custom')
depends=('plasma-workspace')
_pluginid=com.mazelinux.said360

package() {
    install -dm755 "$pkgdir/usr/share/plasma/plasmoids/$_pluginid"
    cp -r "$startdir/contents" "$pkgdir/usr/share/plasma/plasmoids/$_pluginid/"
    install -Dm644 "$startdir/metadata.json" "$pkgdir/usr/share/plasma/plasmoids/$_pluginid/metadata.json"
}
