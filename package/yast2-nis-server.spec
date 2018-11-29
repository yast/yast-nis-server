#
# spec file for package yast2-nis-server
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-nis-server
Version:        4.1.0
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0-only
BuildRequires:  doxygen perl-XML-Writer update-desktop-files yast2-network yast2-nis-client yast2-testsuite
# SuSEFirewall2 replaced by firewalld (fate#323460)
BuildRequires:  yast2 >= 4.0.39
BuildRequires:  yast2-devtools >= 3.1.10
Requires:       yast2-network yast2-nis-client

# SuSEFirewall2 replaced by firewalld (fate#323460)
Requires:       yast2 >= 4.0.39

Provides:	yast2-config-nis-server
Obsoletes:	yast2-config-nis-server
Provides:	yast2-trans-nis-server
Obsoletes:	yast2-trans-nis-server
Obsoletes:	yast2-nis-server-devel-doc

BuildArchitectures:	noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Network Information Services (NIS) Server Configuration

%description 
The YaST2 component for NIS server configuration. NIS is a service
similar to yellow pages.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

# Remove the license from the /usr/share/doc/packages directory,
# it is also included in the /usr/share/licenses directory by using
# the %license tag.
rm -f $RPM_BUILD_ROOT/%{yast_docdir}/COPYING


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/nis_server
%{yast_yncludedir}/nis_server/*.rb
%dir %{yast_moduledir}
%{yast_moduledir}/NisServer.rb
%dir %{yast_clientdir}
%{yast_clientdir}/nis_server.rb
%{yast_clientdir}/nis_server_auto.rb
%{yast_clientdir}/nis-server.rb
%dir %{yast_desktopdir}
%{yast_desktopdir}/nis_server.desktop
%dir %{yast_scrconfdir}
%{yast_scrconfdir}/run_ypwhich_m.scr
%{yast_scrconfdir}/var_yp_securenets.scr
%{yast_scrconfdir}/var_yp_ypservers.scr
%{yast_schemadir}/autoyast/rnc/nis_server.rnc
%{yast_icondir}
%dir %{yast_docdir}
%license COPYING
