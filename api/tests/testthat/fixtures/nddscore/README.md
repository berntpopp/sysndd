# NDDScore test fixtures

Trimmed Zenodo-style release archives for offline importer/job tests. No network.
The archives are generated artifacts and are intentionally gitignored.

- `nddscore_fixture_release.tar.gz` - valid 3-gene / 4-HPO-prediction / 2-term release
  with a correct inner `checksums.sha256`. Internal layout matches the real archive:
  `sysndd_zenodo_dataset/sysndd_prediction_release/`.
- `nddscore_fixture_corrupt_sha256.tar.gz` - same files, but the inner `checksums.sha256`
  line for `nddscore_release.json` is wrong (extract-verification failure case).

Regenerate with `Rscript api/tests/testthat/fixtures/nddscore/make-fixture-archive.R`.
Tests regenerate the archives on demand if they are missing from a fresh checkout.
