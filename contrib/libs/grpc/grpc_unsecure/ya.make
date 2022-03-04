# Generated by devtools/yamaker.

LIBRARY()

WITHOUT_LICENSE_TEXTS()

OWNER(g:cpp-contrib)

LICENSE(Apache-2.0)

PEERDIR(
    contrib/libs/c-ares
    contrib/libs/grpc/grpc
    contrib/libs/grpc/src/core/lib
    contrib/libs/grpc/third_party/address_sorting
    contrib/libs/grpc/third_party/upb
    contrib/libs/zlib
    contrib/restricted/abseil-cpp-tstring/y_absl/status
    contrib/restricted/abseil-cpp-tstring/y_absl/strings
    contrib/restricted/abseil-cpp-tstring/y_absl/strings/cord
    contrib/restricted/abseil-cpp-tstring/y_absl/strings/internal/str_format
)

ADDINCL(
    GLOBAL contrib/libs/grpc/include
    contrib/libs/c-ares/include
    ${ARCADIA_BUILD_ROOT}/contrib/libs/grpc
    contrib/libs/grpc
    contrib/libs/grpc/src/core/ext/upb-generated
    contrib/libs/grpc/third_party/address_sorting/include
    contrib/libs/grpc/third_party/upb
)

NO_COMPILER_WARNINGS()

SRCDIR(contrib/libs/grpc/src/core)

IF (OS_LINUX OR OS_DARWIN)
    CFLAGS(
        -DGRPC_POSIX_FORK_ALLOW_PTHREAD_ATFORK=1
    )
ENDIF()

SRCS(
    ext/filters/client_channel/lb_policy/grpclb/grpclb_channel.cc
    lib/surface/init_unsecure.cc
    plugin_registry/grpc_unsecure_plugin_registry.cc
)

END()
