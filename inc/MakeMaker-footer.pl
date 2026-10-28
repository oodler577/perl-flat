# Included in the generated Makefile.PL; not a dependency on Dist::Zilla.
package MY;
sub postamble {
    return <<'MAKE';

# Override at make install time; 'none' disables completion installation.
FASH_COMPLETION_DIR =

pure_perl_install ::
	$(NOECHO) $(FULLPERLRUN) -I$(INST_LIB) inc/install-fash-completion.pl --bindir "$(DESTINSTALLBIN)" --directory "$(FASH_COMPLETION_DIR)" --destdir "$(DESTDIR)" --packlist "$(DESTINSTALLARCHLIB)/auto/$(FULLEXT)/.packlist"

pure_site_install ::
	$(NOECHO) $(FULLPERLRUN) -I$(INST_LIB) inc/install-fash-completion.pl --bindir "$(DESTINSTALLSITEBIN)" --directory "$(FASH_COMPLETION_DIR)" --destdir "$(DESTDIR)" --packlist "$(DESTINSTALLSITEARCH)/auto/$(FULLEXT)/.packlist"

pure_vendor_install ::
	$(NOECHO) $(FULLPERLRUN) -I$(INST_LIB) inc/install-fash-completion.pl --bindir "$(DESTINSTALLVENDORBIN)" --directory "$(FASH_COMPLETION_DIR)" --destdir "$(DESTDIR)" --packlist "$(DESTINSTALLVENDORARCH)/auto/$(FULLEXT)/.packlist"
MAKE
}
