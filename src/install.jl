# install.jl collects scripts to install many third party libraries 

export install_adept, install_blas, install_openmpi, install_hypre, install_had, install_mfem, install_matplotlib

function install_blas(blas_binary)
    if Sys.iswindows()
        if isfile(joinpath(ADCME.LIBDIR, "openblas.lib"))
            return 
        end 
        if blas_binary
            @info "Downloading prebuilt blas from Github. If you encounter any problem with openblas when using adept, run `install_adept(blas_binary=false)` to compile from source"
            download("https://github.com/kailaix/tensorflow-1.15-include/releases/download/v0.1.0/openblas.lib", joinpath(ADCME.LIBDIR, "openblas.lib"))
            return 
        end
        @info "You are building openblas from source on Windows, and this process may take a long time.
Alternatively, you can place your precompiled binary to $(joinpath(ADCME.LIBDIR, "openblas.lib"))"
        PWD = pwd()
        download("https://github.com/xianyi/OpenBLAS/archive/v0.3.9.zip", joinpath(ADCME.LIBDIR, "OpenBlas.zip"))
        cd(ADCME.LIBDIR)
        run(`cmd /c unzip OpenBLAS.zip`)
        rm("OpenBlas", force=true, recursive=true)
        run(`cmd /c ren OpenBlas-0.3.9 OpenBlas`)
        rm("OpenBlas.zip")
        cd("OpenBlas")
        mkdir("build")
        cd("build")
        ADCME.cmake(CMAKE_ARGS="-DCMAKE_Fortran_COMPILER=flang -DBUILD_WITHOUT_LAPACK=no -DNOFORTRAN=0 -DDYNAMIC_ARCH=ON")
        ADCME.make()
        cd("../build/lib/Release")
        mv("openblas.lib", joinpath(ADCME.LIBDIR, "openblas.lib"))
        cd(PWD)
    else 
        required_file = get_library(joinpath(ADCME.LIBDIR, "openblas"))
        if !isfile(required_file)
            files = readdir(ADCME.LIBDIR)
            files = filter(x->!isnothing(x), match.(r"(libopenblas\S*.dylib)", files))[1]
            if length(files)==0
                CONDA = get_conda()
                run(`$CONDA install -c anaconda libopenblas`)
                files = readdir(ADCME.LIBDIR)
                files = filter(x->!isnothing(x), match.(r"(libopenblas\S*.dylib)", files))[1]
            end
            target = joinpath(ADCME.LIBDIR, files[1])
            symlink(target, required_file)
            @info "Symlink $(required_file) --> $(files[1])"
        end
    end 
end

"""
    install_adept()

Install adept-2 library: https://github.com/rjhogan/Adept-2
"""
function install_adept(; blas_binary::Bool = true)
    change_directory()
    git_repository("https://github.com/ADCMEMarket/Adept-2", "Adept-2")
    cd("Adept-2/adept")
    install_blas(blas_binary)
    cp("$(@__DIR__)/../deps/AdeptCMakeLists.txt", "./CMakeLists.txt", force=true)
    change_directory("build")
    require_cmakecache() do 
        ADCME.cmake()
    end
    if Sys.iswindows()
        require_file("$(ADCME.LIBDIR)/adept.lib") do 
            ADCME.make()
        end
    else
        require_library("$(ADCME.LIBDIR)/adept") do 
            ADCME.make()
        end
    end

        printstyled("""
∘ Add the following lines to CMakeLists.txt 

include_directories(\${LIBDIR}/Adept-2/include)
find_library(ADEPT_LIB_FILE adept HINTS \${LIBDIR})
find_library(LIBOPENBLAS openblas HINTS \${LIBDIR})
message("ADEPT_LIB_FILE=\${ADEPT_LIB_FILE}")
message("LIBOPENBLAS=\${LIBOPENBLAS}")

∘ Add `\${ADEPT_LIB_FILE}` and `\${LIBOPENBLAS}` to `target_link_libraries`
""", color=:green)
end


function install_openmpi()
    filepath = joinpath(@__DIR__, "..", "deps", "install_openmpi.jl")
    include(filepath)
end

function install_hypre()
    filepath = joinpath(@__DIR__, "..", "deps", "install_hypre.jl")
    include(filepath)
end

function install_mfem()
    PWD = pwd()
    change_directory()
    http_file("https://github.com/kailaix/mfem/archive/shared-msvc-dev.zip", "mfem.zip")
    uncompress("mfem.zip", "mfem-shared-msvc-dev")
    change_directory("mfem-shared-msvc-dev/build")
    require_file("CMakeCache.txt") do
        ADCME.cmake(CMAKE_ARGS = ["-DCMAKE_INSTALL_PREFIX=$(joinpath(ADCME.LIBDIR, ".."))", "-SHARED=YES", "-STATIC=NO"])
    end
    require_library("mfem") do 
        ADCME.make()
    end
    require_file(joinpath(ADCME.LIBDIR, get_library_name("mfem"))) do 
        if Sys.iswindows()
            run_with_env(`cmd /c $(ADCME.CMAKE) --install .`)
        else
            run_with_env(`$(ADCME.NINJA) install`)
        end
    end
    if Sys.iswindows()
mfem_h = """
// Auto-generated file.
#undef NO_ERROR 
#undef READ_ERROR 
#undef WRITE_ERROR
#undef ALIAS
#undef REGISTERED
#include "mfem/mfem.hpp"
"""
        open(joinpath(ADCME.LIBDIR, "..",  "include", "mfem.hpp"), "w") do io 
            write(io, mfem_h)
            @info "Fixed mfem.hpp definitions"
        end
    end
    cd(PWD)
end

function install_had()
    change_directory()
    git_repository("https://github.com/kailaix/had", "had")
end

function install_matplotlib()
    PIP = get_pip()
    run(`$PIP install matplotlib`)
    if Sys.isapple() 
        CONDA = get_conda()
        pkgs = run(`$CONDA list`)
        if occursin("pyqt", pkgs)
            return
        end
        if !isdefined(Main, :Pkg)
            error("Package Pkg must be imported in the main module using `import Pkg` or `using Pkg`")
        end
        run(`$CONDA install -y pyqt`)
        Main.Pkg.build("PyPlot")
    end
end