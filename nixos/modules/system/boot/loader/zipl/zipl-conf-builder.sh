#! @bash@/bin/sh -e

shopt -s nullglob

export PATH=/empty
for i in @path@; do PATH=$PATH:$i/bin; done

timeout=
target=/boot
numGenerations=0
installDevice=
default= #


usage() {
    echo "usage: TODO"
    exit 1
}

while getopts "t:c:d:g:i:" opt; do
    case "$opt" in
        t) # U-Boot interprets '0' as infinite and negative as instant boot
            if [ "$OPTARG" -lt 0 ]; then
                timeout=0
            elif [ "$OPTARG" = 0 ]; then
                timeout=-10
            else
                timeout=$((OPTARG * 10))
            fi
            ;;
        c) default="$OPTARG" ;;
        d) target="$OPTARG" ;;
        g) numGenerations="$OPTARG" ;;
        i) installDevice="$OPTARG" ;;
        \?) usage ;;
    esac
done

[ "$timeout" = "" -o "$default" = "" ] && usage

echo TARGET = $target
mkdir -p $target/{nixos,zipl}
ls -la $target
echo DEFAULT = $default

tmpFile="$target/zipl/zipl.conf.tmp.$$"

cat > $tmpFile <<EOF
# generated file, all changes will be lost on nixos-rebuild
#
# TODO include a howto on how to temporarily override the boospec
[defaultboot]
defaultmenu = menu1

EOF


# Copy a file from the Nix store to $target/nixos.
declare -A filesCopied

# Convert a path to a file in the Nix store such as
# /nix/store/<hash>-<name>/file to <hash>-<name>-<file>.
cleanName() {
    local path="$1"
    echo "$path" | sed 's|^/nix/store/||' | sed 's|/|-|g'
}

copyToKernelsDir() {
    local src=$(readlink -f "$1")
    local dst="$target/nixos/$(cleanName $src)"
    # Don't copy the file if $dst already exists.  This means that we
    # have to create $dst atomically to prevent partially copied
    # kernels or initrd if this script is ever interrupted.
    if ! test -e $dst; then
        local dstTmp=$dst.tmp.$$
        cp -r $src $dstTmp
        mv $dstTmp $dst
    fi
    filesCopied[$dst]=1
    result=$dst
}

# Copy its kernel, initrd and dtbs to $target/nixos, and echo out an
# extlinux menu entry
addEntry() {
    local path=$(readlink -f "$1")
    local tag="$2" # Generation number or 'default'

    if ! test -e $path/kernel -a -e $path/initrd; then
        return
    fi

    copyToKernelsDir "$path/kernel"; kernel=$result
    copyToKernelsDir "$path/initrd"; initrd=$result
    echo "[nixos-$tag]"
    echo "target = $target"
    echo "image = $target/nixos/$(basename $kernel)"
    echo "ramdisk = $target/nixos/$(basename $initrd)"
    echo "parameters = \"$path/init $(cat ${default}/kernel-params)\""
    echo
}


addEntry $default default >> $tmpFile


if [ "$numGenerations" -gt 0 ]; then
    # Add up to $numGenerations generations of the system profile to the menu,
    # in reverse (most recent to least recent) order.
    for generation in $(
            (cd /nix/var/nix/profiles && ls -d system-*-link) \
            | sed 's/system-\([0-9]\+\)-link/\1/' \
            | sort -n -r \
            | head -n $numGenerations); do
        link=/nix/var/nix/profiles/system-$generation-link
        addEntry $link "${generation}-default"
        for specialisation in $(
            ls /nix/var/nix/profiles/system-$generation-link/specialisation \
            | sort -n -r); do
            link=/nix/var/nix/profiles/system-$generation-link/specialisation/$specialisation
            addEntry $link "${generation}-${specialisation}"
        done
    done >> $tmpFile
fi


cat >> $tmpFile  <<EOF
:menu1
target = /boot
1 = nixos-default
default = 1
EOF


mv -f $tmpFile $target/zipl/zipl.conf

zipl -d $installDevice --config=$target/zipl/zipl.conf
