#!/bin/bash
# This script contains common code for building PyNE on various Debian-derived systems
#

function check_repo() {

    repo_name=$1

    if [ -d $repo_name ] ; then
        read -p "Delete the existing $repo_name directory and all contents? (y/n) " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]] ; then
            rm -rf $repo_name
        fi
    fi

}

function build_moab {

    # Install MOAB
    cd ${install_dir}
    mkdir -p moab
    cd moab
    check_repo moab-repo
    git clone --branch Version5.1.0 --single-branch https://bitbucket.org/fathomteam/moab moab-repo
    cd moab-repo
    mkdir -p build
    cd build
    cmake ../ -DENABLE_HDF5=ON \
              -DBUILD_SHARED_LIBS=ON \
              -DENABLE_PYMOAB=ON \
              -DENABLE_BLASLAPACK=OFF \
              -DENABLE_FORTRAN=OFF \
              -DCMAKE_INSTALL_PREFIX=${install_dir}/moab
    make
    make install
    export LD_LIBRARY_PATH=${install_dir}/moab/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=${install_dir}/moab/lib:$LIBRARY_PATH
    
    echo "export LD_LIBRARY_PATH=${install_dir}/moab/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
    echo "export LIBRARY_PATH=${install_dir}/moab/lib:\$LIBRARY_PATH" >> ~/.bashrc
    echo "export CPLUS_INCLUDE_PATH=${install_dir}/moab/include:\$CPLUS_INCLUDE_PATH" >> ~/.bashrc
    echo "export C_INCLUDE_PATH=${install_dir}/moab/include:\$C_INCLUDE_PATH" >> ~/.bashrc

    PYTHON_VERSION=$(python -c 'import sys; print(sys.version.split('')[0][0:3])')
    echo "if [ -z \"\$PYTHONPATH\" ]" >> ~/.bashrc
    echo "then" >> ~/.bashrc >> ~/.bashrc
    echo "  export PYTHONPATH=$install_dir/moab/lib/python${PYTHON_VERSION}/site-packages" >> ~/.bashrc
    echo "else" >> ~/.bashrc
    echo "  export PYTHONPATH=$install_dir/moab/lib/python${PYTHON_VERSION}/site-packages:\$PYTHONPATH" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
}

function build_dagmc {

    # Install DAGMC
    cd ${install_dir}
    check_repo dagmc
    mkdir -p dagmc
    cd dagmc
    git clone https://github.com/svalinn/DAGMC.git dagmc-repo
    cd dagmc-repo
    git checkout develop
    mkdir build
    cd build
    cmake .. -DMOAB_DIR=${install_dir}/moab \
             -DBUILD_STATIC_LIBS=OFF \
             -DCMAKE_INSTALL_PREFIX=${install_dir}/dagmc
    make
    make install
}

function install_pyne {

    # Install PyNE
    cd $install_dir
    check_repo pyne
    git clone https://github.com/pyne/pyne.git
    cd pyne
    if [ $1 == 'stable' ] ; then
        TAG=$(git describe --abbrev=0 --tags)
        git checkout tags/`echo $TAG` -b `echo $TAG`
    fi
    python setup.py install --user -- -DMOAB_LIBRARY=$install_dir/moab/lib -DMOAB_INCLUDE_DIR=$install_dir/moab/include
    echo "export PATH=$HOME/.local/bin:\$PATH" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=$HOME/.local/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
    echo "alias build_pyne='python setup.py install --user -- -DMOAB_LIBRARY=$install_dir/moab/lib -DMOAB_INCLUDE_DIR=$install_dir/moab/include'" >> ~/.bashrc
PYTHON_VERSION=$(python -c 'import sys; print(sys.version.split('')[0][0:3])')
echo "  export PYTHONPATH=~/.local/lib/python${PYTHON_VERSION}/site-packages:\$PYTHONPATH" >> ~/.bashrc
}

function nuc_data_make {

    # Generate nuclear data file
    export LD_LIBRARY_PATH=$HOME/.local/lib:$LD_LIBRARY_PATH
    ./scripts/nuc_data_make

}

function test_pyne {

    cd tests

    # check which python version to run correct tests
    version=`python -c 'import sys; print(sys.version_info[:][0])'`

    # Run all the tests
    if [ $version == '2' ] ; then
        source ./travis-run-tests.sh python2
    elif [ $version == '3' ] ; then
        source ./travis-run-tests.sh python3
    fi
}


set -euo pipefail
IFS=$'\n\t'

# system update
eval brew update
eval brew install $brew_package_list
export PATH="$HOME/.local/bin:$PATH"
eval sudo pip3 install $pip_package_list

install_dir=$HOME/opt
mkdir -p $install_dir


build_moab

install_pyne $1

source ~/.bashrc

nuc_data_make

test_pyne $1

echo "Run 'source ~/.bashrc' to update environment variables. PyNE may not function correctly without doing so."
echo "PyNE build complete. PyNE can be rebuilt with the alias 'build_pyne' executed from $install_dir/pyne"
