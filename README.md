<p align="center">
  <a href="https://sysndd.dbmr.unibe.ch/">
    <img src="app/public/img/icons/android-chrome-192x192.png" alt="SysNDD logo" width="192" height="192">
  </a>
</p>

<h3 align="center">
SysNDD is the expert curated database of gene-inheritance-disease relationships in <mark>neurodevelopmental</mark> <mark>disorders</mark> (NDD).
</h3>

## The SysNDD GitHub repository

This repository is for development of our SysNDD web application (app), application programming interface (api) and relational database (db). Browse the sub-foldes to view the respective readme files and source code.

## Table of contents

- [Quick start](#quick-start) 🏁
- [Documentation](#documentation) 📝
- [Contributing and community](#contributing-and-community) 👥
- [Bugs and feature requests](#bugs-and-feature-requests) 🪲 & 🌟
- [Creators](#creators-and-contributors) 👩‍🔬
- [Support and Funding](#support-and-funding) 🤗
- [Credits and acknowledgement](#credits-and-acknowledgments) 👍
- [Copyright and license](#copyright-and-license) ©️

## Quick start

The SysNDD installation depends on docker and docker-compose.
If these are installed the project can be installed locally using the provided shell script:

```
bash deployment.sh "<config.tar.gz>"
```

- A dummy config file for local deployment will be provided in this repository.
- Data and a script to populate the MySQL database will be provided in this repository.

## Documentation

Please explore [The SysNDD Documentation](https://berntpopp.github.io/sysndd/) hosted on GitHub pages and build with bookdown.

To help you get the most out of the SysNDD website, we are putting together a series of [video tutorials](https://berntpopp.github.io/sysndd/tutorial-videos.html).

## Contributing and community

To contribute in curating novel entries to our database you can register for a new reviewer/ curator [account on the SysNDD page](https://sysndd.dbmr.unibe.ch/Register).

Ask questions, report bugs and chat about SysNDD in general using our [Github discussions](https://github.com/berntpopp/sysndd/discussions) page.

## Bugs and feature requests

If you have technical problems using SysNDD or requests regarding the data or functionality, please contact us at support [at] sysndd.org.

## Creators and contributors

**Bernt Popp** (SysNDD)

- <https://twitter.com/berntpopp>
- <https://github.com/berntpopp>
- <https://orcid.org/0000-0002-3679-1081>
- <https://scholar.google.com/citations?user=Uvhu3t0AAAAJ>
- <https://www.berntpopp.com>

**Christiane Zweier** (SysID, SysNDD)

- <https://orcid.org/0000-0001-8002-2020>
- <https://scholar.google.com/citations?user=KE0N1r8AAAAJ>

**Annette Schenck** (SysID)

- <https://twitter.com/annette_schenck>
- <https://orcid.org/0000-0002-6918-3314>
- <https://www.schencklab.com>

**Melek Firat Altay** (SysNDD)

- <https://twitter.com/firataltay>
- <https://github.com/altay-epfl>
- <https://orcid.org/0000-0002-8174-5631>
- <https://linkedin.com/in/melek-firat-altay>

## Support and Funding

The current SysNDD database development is supported by:

- DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1 to Bernt Popp.
- DFG (Deutsche Forschungsgemeinschaft) grant ZW184/6-1 to Christiane Zweier.
- ITHACA ERN through Alain Verloes .
  The previous SysID database and data curation was supported by:
- The European Union’s FP7 large scale integrated network GenCoDys (HEALTH-241995) Martijn A Huynen . and Annette Schenck.
- VIDI and TOP grants (917-96-346, 912-12-109) from The Netherlands Organisation for Scientific Research (NWO) to Annette Schenck.
- DFG (Deutsche Forschungsgemeinschaft) grants ZW184/1-1 and -2 to Christiane Zweier.
- the IZKF (Interdisziplinäres Zentrum für Klinische Forschung) Erlangen to Christiane Zweier.
- ZonMw grant (NWO, 907-00-365) to Tjitske Kleefstra.

## Credits and acknowledgement

We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the Radboud University Medical Center Nijmegen, The Netherlands, for building SysID and supporting it for many years.
We would also like to thank all past users for using SysID and for constructive feedback, thus making the sometimes tedious updates and re-organization into the new SysNDD database worthwhile. Since recently, Alain Verloes and ERN ITHACA provide valuable encouragement and support by initiating and supporting the data integration with Orphanet and helping with the recruitment of expert curators.

## Copyright and license

- All code from this project is licensed under the "MIT No Attribution" (MIT-0) License - see the LICENSE.md file for details.
- The project data, website and api usage are licensed under the "Attribution 4.0 International" (CC BY 4.0) License - see the [https://creativecommons.org/licenses/by/4.0/](https://creativecommons.org/licenses/by/4.0/) for details.
