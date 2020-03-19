"""Tests for default molecule scenario."""

import io
import json
import os
import re

import testinfra.utils.ansible_runner


testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(  # pylint: disable=invalid-name
    os.environ["MOLECULE_INVENTORY_FILE"]
).get_hosts("localhost")

DOWNLOAD_PATH = "/tmp"

# pylint: disable=line-too-long
CSV_RE = r"([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})_openshift_usage_report\.(\d+(_\d+)?)\.csv"  # noqa: E501


def test_download_path(host):
    """Test download path."""
    assert host.file(DOWNLOAD_PATH).exists
    assert host.file(DOWNLOAD_PATH).is_directory


def test_archive_file(host):
    """Test archive file."""
    archive_re = r"cost(_\d+)?.tar.gz"
    list_dir = host.run(f"ls -1 {DOWNLOAD_PATH}/*.tar.gz").stdout.split()

    # files exist
    assert len(list_dir) > 0
    for file_name in list_dir:
        assert re.search(archive_re, file_name)
        assert host.file(file_name).size <= (1024 * 1024)
        tarfiles = host.run(
            f"tar -tf {DOWNLOAD_PATH}/{file_name}").stdout.split()
        for tfile in tarfiles:
            ext = tfile.split(".")[-1]
            assert ext in ["csv", "json"]
            if ext == "csv":
                assert re.search(CSV_RE, tfile)
            elif ext == "json":
                assert tfile == "manifest.json"
