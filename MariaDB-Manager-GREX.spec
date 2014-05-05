%define _topdir	 	%(echo $PWD)/
%define name		MariaDB-Manager-GREX
%define release		##RELEASE_TAG##
%define version 	##VERSION_TAG##
%define install_path	/usr/local/sbin/

BuildRoot:		%{buildroot}
BuildArch:		noarch
Summary: 		MariaDB Manager Database Node Agent
License: 		GPL
Name: 			%{name}
Version: 		%{version}
Release: 		%{release}
Source: 		%{name}-%{version}-%{release}.tar.gz
Prefix: 		/
Group: 			Development/Tools
Requires:		yum rpm sudo chkconfig sed coreutils util-linux curl >= 7.19.7 net-tools percona-xtrabackup jq nc rsync iproute grep findutils gawk MariaDB-Galera-Server =5.5.36, galera =25.3.5
#BuildRequires:		

%description
MariaDB Manager is a tool to manage and monitor a set of MariaDB
servers using the Galera multi-master replication form Codership.
As part of the management infrastructure a set of agent scripts are
installed on each of the database nodes.

%prep

%setup -q

%build

%post

#useradd skysqlagent
# is  /home/skysqlagent/.ssh/ automatically created?? 

#echo "Please put public key to /home/skysqlagent/.ssh/authorized_keys"
#echo "set permissions:"
#echo "chown skysqlagent /home/skysqlagent/.ssh/authorized_keys"
#echo "chmod 600 /home/skysqlagent/.ssh/authorized_keys"
#echo "and restart sshd"

# grant root to NodeCommand.sh
#echo "skysqlagent ALL=NOPASSWD: /usr/local/sbin/skysql/NodeCommand.sh" >> /etc/sudoers
touch /var/log/skysql-remote-exec.log
chown skysqlagent:skysqlagent /var/log/skysql-remote-exec.log

# comment "requiretty" in the sudoers
#sed "s/Defaults.*requiretty/#Defaults     requiretty/g" /etc/sudoers > /etc/sudoers.tmp
#mv /etc/sudoers.tmp /etc/sudoers

%install
mkdir -p $RPM_BUILD_ROOT%{install_path}
cp -r skysql $RPM_BUILD_ROOT%{install_path}

%clean

%files
%defattr(-,root,root)
%{install_path}skysql/*

%changelog
