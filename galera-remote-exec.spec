%define _topdir	 	%(echo $PWD)/
%define name		galera-remote-exec
%define release		##RELEASE_TAG##
%define version 	##VERSION_TAG##
%define buildroot 	%{_topdir}/%{name}-%{version}-%{release}root
%define install_path	/usr/local/sbin/

BuildRoot:		%{buildroot}
BuildArch:		noarch
Summary: 		galera-remote-exec
License: 		GPL
Name: 			%{name}
Version: 		%{version}
Release: 		%{release}
Source: 		%{name}-%{version}-%{release}.tar.gz
Prefix: 		/
Group: 			Development/Tools
Requires:		curl net-tools
#BuildRequires:		

%description
galera-remote-exec

%prep

%setup -q

%build

%post

useradd skysqlagent
# is  /home/skysqlagent/.ssh/ automatically created?? 

echo "Please put public key to /home/skysqlagent/.ssh/authorized_keys"
echo "set permissions:"
echo "chown skysqlagent /home/skysqlagent/.ssh/authorized_keys"
echo "chmod 600 /home/skysqlagent/.ssh/authorized_keys"
echo "and restart sshd"

# grant root to NodeCommand.sh
echo "skysqlagent ALL=NOPASSWD: /usr/local/sbin/skysql/NodeCommand.sh" >> /etc/sudoers
touch /var/log/skysql-remote-exec.log
chown skysqlagent:skysqlagent /var/log/skysql-remote-exec.log

# comment "requiretty" in the sudoers
sed "s/Defaults.*requiretty/#Defaults     requiretty/g" /etc/sudoers > /etc/sudoers.tmp
mv /etc/sudoers.tmp /etc/sudoers

%install
mkdir -p $RPM_BUILD_ROOT%{install_path}
cp -r skysql $RPM_BUILD_ROOT%{install_path}

%clean

%files
%defattr(-,root,root)
%{install_path}skysql/*

%changelog
