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



# 参数	                类型	    默认值	    说明
# pattern	            位置参数	必填	    要搜索的字符串（支持正则表达式）
# --ignore-case / -i	标志	    无	        匹配时忽略大小写
# --csv-separator	    字符串	    ","	        CSV/TSV 分隔符，支持 ; | \t 等
# --stream	            标志	    无	        对流式处理 CSV/TSV（逐行 split）


# 在递归查找的所有 Excel 文件中搜索指定字符串
# 输入: 要搜索的字符串
# 输出: 每一行格式为 "相对路径 -- 匹配的单元格内容"
def se [
    pattern: string
    --ignore-case (-i),
    --csv-separator: string = ",",
    --stream
] {
    let search_pattern = if $ignore_case { $"(?i)($pattern)" } else { $pattern }

    let separator = (
        if $csv_separator == '\\t' { char tab }
        else { $csv_separator }
    )

    let extensions = ['xlsx', 'xls', 'xlsm', 'csv', 'tsv']

    let all_files = (ls **/* | get name)
    let table_files = ($all_files | where {|f|
        ($f | path parse | get extension | str downcase) in $extensions
    })

    if ($table_files | is-empty) {
        print $"未找到任何支持的表格文件（扩展名: ($extensions | str join ', ')）"
        return
    }

    for $file in $table_files {
        let ext = ($file | path parse | get extension | str downcase)
        if $ext in ['xlsx', 'xls', 'xlsm'] {
            search_in_excel $file $search_pattern
        } else if $ext in ['csv', 'tsv'] {
            if $stream {
                search_in_csv_streaming $file $separator $search_pattern
            } else {
                search_in_csv_standard $file $separator $search_pattern
            }
        }
    }
}

# 标准方式：使用 from csv 全量加载（支持引号转义，但内存占用高）
def search_in_csv_standard [file: string, separator: string, pattern: string] {
    let table = open $file | from csv --separator $separator
    for $row in $table {
        for $cell in ($row | values) {
            if $cell != null {
                let cell_str = ($cell | into string)
                if ($cell_str =~ $pattern) {
                    print $"($file) -- ($cell_str)"
                }
            }
        }
    }
}

# 流式处理：逐行 split，不处理引号，内存友好
def search_in_csv_streaming [file: string, separator: string, pattern: string] {
    open --raw $file | lines | each { |line|
        if ($line | is-empty) { return }
        let fields = ($line | split row $separator)
        for $field in $fields {
            let trimmed = ($field | str trim)
            if ($trimmed != '' and ($trimmed =~ $pattern)) {
                print $"($file) -- ($trimmed)"
            }
        }
    }
}

# 在 Excel 文件中搜索（一次性加载所有工作表）
def search_in_excel [file: string, pattern: string] {
    let workbook = (open $file)
    let tables = if ($workbook | describe) =~ 'record' {
        $workbook | values
    } else {
        [$workbook]
    }
    for $table in $tables {
        for $row in $table {
            for $cell in ($row | values) {
                if $cell != null {
                    let cell_str = ($cell | into string)
                    if ($cell_str =~ $pattern) {
                        print $"($file) -- ($cell_str)"
                    }
                }
            }
        }
    }
}