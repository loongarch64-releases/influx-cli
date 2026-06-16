#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=influxdata
UPSTREAM_REPO=influx-cli
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"

mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

# ==========================================
# 👇 用户自定义构建逻辑 (示例)
# ==========================================

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    git clone -b "${VERSION}" --depth 1 "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}.git" "${SRCS}/${VERSION}"
    pushd "${SRCS}/${VERSION}"
    go get go.etcd.io/bbolt@v1.3.12
    go mod tidy
    popd

    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    local MAJOR_VER="$(echo ${VERSION#v} | cut -d. -f1)"
    local MINOR_VER="$(echo ${VERSION#v} | cut -d. -f2)"

    pushd "${SRCS}/${VERSION}"
    if [ "${MAJOR_VER}" -eq 2 ] && [ "${MINOR_VER}" -le 6 ]; then
	local LDFLAGS=" -X main.date=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -X main.version=$VERSION"
	go build -ldflags "$LDFLAGS" -o bin/linux/loong64/ ./cmd/influx
    else
        make
    fi
    popd

    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    local PRODUCT="${DISTS}/${VERSION}/influx"
    local BUILD_OUTPUT="${SRCS}/${VERSION}/bin/linux/loong64/influx"
    cp "$BUILD_OUTPUT" "$PRODUCT"
    chown -R "${HOST_UID}:${HOST_GID}" "${DISTS}" "${SRCS}"
    
    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    prepare
    build
    post_build
}

main

# ==========================================
# 👆 自定义逻辑结束
# ==========================================

cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
