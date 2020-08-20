#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright 2020 Red Hat, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
"""Query Prometheus for OpenShift cluster metrics."""

import argparse
import csv
import datetime
import logging
import json
import requests
import sys
import time


# default prometheus query
DEFAULT_PROMETHEUS = 'https://thanos-querier.openshift-monitoring.svc:9091/api/v1/query_range'
DEFAULT_QUERY = "up"

# logging
LOG = logging.getLogger(__name__)
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_VERBOSITY = [logging.ERROR, logging.WARNING, logging.INFO, logging.DEBUG]
logging.basicConfig(format=LOG_FORMAT, level=logging.ERROR, stream=sys.stdout)


def parse_args():
    """Handle CLI arg parsing."""
    parser = argparse.ArgumentParser(
        description="Cost Management prometheus query script", prog=sys.argv[0])

    # required args
    parser.add_argument("-c", "--cacert", required=True,
                        help="path to cacert file")
    
    parser.add_argument("-b", "--bearer", required=True,
                        help="Bearer token value")
    
    parser.add_argument("-p", "--prometheus-url", required=True,
                        default=DEFAULT_PROMETHEUS, help="Prometheus host and query api")
    
    parser.add_argument("-q", "--query", required=True,
                        default=DEFAULT_QUERY, help="Prometheus query")

    parser.add_argument("-v", "--verbosity", action="count",
                        default=0, help="increase verbosity (up to -vvv)")
    return parser.parse_args()


def execute_prom_query(prometheus_url, query):
    """Query prometheus for metrics."""
    results = None
    end = datetime.datetime.now().replace(minute=0, second=0, microsecond=0)
    start = end - datetime.timedelta(hours=1)
    step = '1h'
    req_params={ 
        'query': query,
        'start': start,
        'end': end,
        'step': step}
    response = requests.get(prometheus_url, params=req_params)
    results = response.json()['data']['result']

    return results


if "__main__" in __name__:
    args = parse_args()
    if args.verbosity:
        LOG.setLevel(LOG_VERBOSITY[args.verbosity])
    LOG.debug("CLI Args: %s", args)

    json_results = execute_prom_query(args.prometheus_url, args.query)
    print(json_results)