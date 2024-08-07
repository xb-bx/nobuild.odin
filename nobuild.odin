package nobuild
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:mem"
import "core:sys/windows"
import "core:sys/unix"

run :: proc(name: string, args: ..string) {
    if !try_run(name, ..args) {
        exit(1)
    }
}
when ODIN_OS == .Windows {
    try_run :: proc(name: string, args: ..string) -> bool {
        using strings
        start_info := windows.STARTUPINFOW {}
        proc_info := windows.PROCESS_INFORMATION {}

        builderobj : Builder = {}
        builder := &builderobj
        builder_init(builder)
        write_string(builder, name)
        for arg in args {
            write_rune(builder, ' ')
            write_rune(builder, '"')
            for c in arg {
                if c != '"' {
                    write_rune(builder, c)
                }    
                else {
                    write_rune(builder, '\\')
                    write_rune(builder, c)
                }
            }
            write_rune(builder, '"')
        }
        cmdline := to_string(builder^)
        fmt.println(cmdline)
        ok := windows.CreateProcessW(nil, windows.utf8_to_wstring(cmdline), nil, nil, true, 0, nil, nil, &start_info, &proc_info)
        if !ok {
            fmt.printf("ERROR: failed to run %s\n", name)
            return false
            
        }
        windows.WaitForSingleObject(proc_info.hProcess, windows.INFINITE)
        exitcode: windows.DWORD = 0
        windows.GetExitCodeProcess(proc_info.hProcess, &exitcode) 
        if exitcode != 0 {
            fmt.printf("ERROR: Process %s returned exit code %i", name, exitcode)
            return false
        }
        return true

    }
    cd :: proc(dir: string) {
        os.change_directory(dir)
    }

    try_rmdir :: proc(dir: string) -> bool {
        if !os.exists(dir) {
            fmt.printf("ERROR: Directory %s does not exists\n", dir)
            return false
        }
        if !os.is_dir(dir) {
            fmt.printf("ERROR: %s is not a directory\n", dir)
            return false
        }
        handle, err := os.open(dir, os.O_RDWR)
        if err != os.ERROR_NONE {
            fmt.printf("ERROR: failed to open dir %s %i\n", dir, err)
            return false
        }
        fi, errno := os.read_dir(handle, -1)
        if errno != os.ERROR_NONE {
            fmt.printf("ERROR: failed to open dir %s\n", dir)
            return false 
        }
        for file in fi {
            if file.is_dir {
                if !try_rmdir(file.fullpath) {
                    return false
                }
            } else {
                err = os.remove(file.fullpath)
                if err != os.ERROR_NONE {
                    fmt.printf("ERROR: failed to delete file %s\n", file.fullpath)
                    return false
                }
            }
        } 
        os.close(handle)
        err = os.remove_directory(dir)
        if err != os.ERROR_NONE {
            fmt.printf("ERROR: failed to delete directory %s\n", dir)
            return false
        }
        return true
    }
}
directory_entries :: proc(dir:string) -> []os.File_Info {
    when ODIN_OS == .Linux {
        handle, err := os.open(dir, 65536)
    } else {
        handle, err := os.open(dir, os.O_RDWR)
    }
    fi, errno := os.read_dir(handle, -1)
    os.close(handle)
    return fi
}
when ODIN_OS == .Linux {
    cd :: proc(dir: string) {
        dir := strings.clone_to_cstring(dir)
        unix.sys_chdir(dir)
    }
    try_run :: proc(name: string, args: ..string) -> bool {
        name := name
        fmt.print(name, "")
        for arg in args {
            fmt.print(arg, "")
        }
        fmt.println()
        pid, err := os.fork()
        if err != os.ERROR_NONE {
            fmt.printf("ERROR: Failed to run %s\n", name)
            return false
        }
        if pid == 0 {
            err := os.execvp(name, args)
            if err != 0 {
                fmt.printf("ERROR: Failed to run %s %i\n", name, err)
                return false
            }
        }
        else {
            // For some reason odin standard lib does not have wait for pid function
            SYS_waitid :: 247
            a, _ := mem.alloc(1024)
            
            code := intrinsics.syscall(SYS_waitid, 1, uintptr(pid), 0, 4, uintptr(a))
            mem.free(a)
        }
        return true 
    }
    try_rmdir :: proc(dir: string) -> bool {
        if !os.exists(dir) {
            fmt.printf("ERROR: Directory %s does not exists\n", dir)
            return false
        }
        if !os.is_dir(dir) {
            fmt.printf("ERROR: %s is not a directory\n", dir)
            return false
        }
        handle, err := os.open(dir, 65536)
        if err != os.ERROR_NONE {
            fmt.printf("ERROR: failed to open dir %s %i\n", dir, err)
            return false
        }
        fi, errno := os.read_dir(handle, -1)
        if errno != os.ERROR_NONE {
            fmt.printf("ERROR: failed to open dir %s\n", dir)
            return false 
        }
        for file in fi {
            if file.is_dir {
                if !try_rmdir(file.fullpath) {
                    return false
                }
            } else {
                err = os.remove(file.fullpath)
                if err != os.ERROR_NONE {
                    fmt.printf("ERROR: failed to delete file %s\n", file.fullpath)
                    return false
                }
            }
        } 
        os.close(handle)
        err = os.remove_directory(dir)
        if err != os.ERROR_NONE {
            fmt.printf("ERROR: failed to delete directory %s\n", dir)
            return false
        }
        return true
    }
}

exit :: proc(err: int = 0) {
    os.exit(err)
}
exit_if_true :: proc(cond: bool) {
    if cond {
        exit(1) 
    }
}
rmdir :: proc(dir: string) {
    if !try_rmdir(dir) {
        exit(1)
    }
}
pwd :: proc() -> string {
    return os.get_current_directory()
} 
concat :: proc(strs: ..string) -> string {
    str, _ := strings.concatenate(strs)
    return str
}
try_mkdir :: proc(dir: string) -> bool {
    return os.make_directory(dir) != os.ERROR_NONE
}

mkdir :: proc(dir: string) {
    if !try_mkdir(dir) {
        exit(1)
    }
}
list_files :: proc(dir: string = ".") -> []os.File_Info{
    handle, err := os.open(dir, 65536)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", dir)
        exit(int(err))
    }
    fi, errno := os.read_dir(handle, -1)
    if errno != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", dir)
        os.exit(int(err))
    }
    return fi
} 
_cp_dir :: proc(from: string, to: string) -> bool {
    if !os.is_dir(to) {
        fmt.printf("ERROR: %s is not a directory\n", from)
        return false
    }
    handle, err := os.open(from, 65536)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", from)
        return false
    }
    fi, errno := os.read_dir(handle, -1)
    if errno != os.ERROR_NONE {
        fmt.printf("ERROR: failed to open dir %s\n", from)
        return false 
    }
    new_path := concat(to, "/", file_name(from))
    mkdir(new_path)
    for file in fi {
    
        if file.is_dir {
            if !_cp_dir(file.fullpath, new_path) {
                fmt.printf("ERROR: Failed to copy dir %s\n", file.fullpath) 
                return false
            }
        } 
        else {
            if !_cp_file(file.fullpath, new_path) {
                fmt.printf("ERROR: Failed to copy file %s\n", file.fullpath) 
                return false
            }
        }
    }
    return true
}

_cp_file :: proc(from: string, to:string) -> bool {
    to := to
    if !os.exists(from) {
        fmt.printf("ERROR: File %s doesn't exists\n", from)
        return false
    }
    if os.is_dir(to) {
        to = concat(to, "/", file_name(from)) 
    }
    fromhandle, err := os.open(from, os.O_RDONLY)
    if err != os.ERROR_NONE {
        fmt.printf("ERROR: Can't open file %s\n", from)
        return false
    }
    fromdata, success := os.read_entire_file_from_handle(fromhandle)
    if !os.write_entire_file(to, fromdata, true) {
        fmt.printf("ERROR: Can't write file %s\n", to)
        return false
    }
    return true
} 
file_name :: proc(file: string) -> string {
    return filepath.base(file) 
}
try_cp :: proc(from: string, to: string) -> bool {
    if os.is_dir(from) {
        return _cp_dir(from, to)
    }
    else {
        return _cp_file(from, to)
    }
}


Optimization :: enum {
    none,
    minimal,
    size,
    speed,
}
build_mode_to_string :: proc(build_mode: runtime.Odin_Build_Mode_Type) -> string {
    switch build_mode {
        case .Dynamic:
            return "dynamic"
        case .Static:
            return "static"
        case .Executable:
            return "exe"
        case .Object:
            return "object"
        case .Assembly:
            return "asm"
        case .LLVM_IR:
            return "llvm"
    }
    return "exe"
}
odin_build :: proc(path: string, output: string = "", collections: map[string]string = nil, define: map[string]string=nil, optimization: Optimization = .none, additional_args: []string = nil, build_mode: runtime.Odin_Build_Mode_Type = .Executable) {
    
    
    args := make([dynamic]string)
    defer delete(args)
    append(&args, "build")
    append(&args, path)
    allocated_args := make([dynamic]string)
    for name,colpath in collections {
        append(&allocated_args, fmt.aprintf("-collection:%s=%s", name, colpath))
    }
    for name,value in define {
        append(&allocated_args, fmt.aprintf("-define:%s=%s", name, value))
    }
    
    defer {
        for arg in allocated_args {
            delete(arg)
        }
        delete(allocated_args)
    }
    if output != "" {
        append(&allocated_args, fmt.aprintf("-out:%s", output))
    }
    append(&allocated_args, fmt.aprintf("-o:%s", optimization))
    append(&allocated_args, fmt.aprintf("-build-mode:%s", build_mode_to_string(build_mode)))
    if additional_args != nil {
        append_elems(&args, ..additional_args)
    }
    append_elems(&args, ..allocated_args[:])

    run("odin", ..args[:])
} 

cp :: proc(from: string, to: string) {
    if !try_cp(from, to) {
        exit(1)
    }
}
