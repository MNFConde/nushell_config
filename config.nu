# config.nu
#
# Installed by:
# version = "0.111.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R
$env.config.shell_integration.osc133 = false
$env.config.buffer_editor = "code"
$env.use_ansi_coloring = true

def greet [name] {
    $"Hello, ($name)!"
}

def --env setproxy [port: int = 7897] {
    let proxy_url = $"127.0.0.1:($port)"
    let proxy_http = $"http://($proxy_url)"
    let proxy_https = $"http://($proxy_url)" # Clash 只支持 http 明文代理
    
    # 直接修改 $env，不需要 load-env 或 export-env
    $env.http_proxy = $proxy_http
    $env.https_proxy = $proxy_https
    $env.HTTP_PROXY = $proxy_http
    $env.HTTPS_PROXY = $proxy_https
    
    print $"(ansi green)✓ 代理已设置: ($proxy_url)(ansi reset)"
    check-proxy
}

def --env unsetproxy [] {
    hide-env http_proxy
    hide-env https_proxy
    hide-env HTTP_PROXY
    hide-env HTTPS_PROXY
    
    print $"(ansi yellow)✓ 代理已取消(ansi reset)"
    check-proxy
}

def check-proxy [] {
    let proxy: string = ($env.http_proxy? | default "")
    
    if ($proxy | is-not-empty) {
        print $"(ansi green)当前代理: ($proxy | str substring 7..)(ansi reset)"
        try {
            let ip = (curl -s --max-time 5 https://api.ipify.org | str trim)
            print $"(ansi cyan)代理测试成功，出口 IP: ($ip)(ansi reset)"
        } catch {
            print $"(ansi red)代理测试失败(ansi reset)"
        }
    } else {
        print $"(ansi red)当前无代理(ansi reset)"
    }
}

source ./file_search.nu

greet "Morr"