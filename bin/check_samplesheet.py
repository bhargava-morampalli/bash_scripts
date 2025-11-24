#!/usr/bin/env python3

"""
Validate and parse samplesheet for RNA modification coverage benchmarking pipeline.

Expected samplesheet format (CSV):
sample,condition,fastq
native_1,native,/path/to/native_1.fastq.gz
native_2,native,/path/to/native_2.fastq.gz
native_3,native,/path/to/native_3.fastq.gz
ivt_1,ivt,/path/to/ivt_1.fastq.gz
ivt_2,ivt,/path/to/ivt_2.fastq.gz
ivt_3,ivt,/path/to/ivt_3.fastq.gz
"""

import argparse
import csv
import logging
import sys
from pathlib import Path

logger = logging.getLogger()


class RowChecker:
    """
    Define a service that can validate and transform each given row.
    """

    VALID_CONDITIONS = ["native", "ivt"]
    VALID_FORMATS = [".fastq", ".fq", ".fastq.gz", ".fq.gz"]

    def __init__(
        self,
        sample_col="sample",
        condition_col="condition",
        fastq_col="fastq",
        **kwargs,
    ):
        """
        Initialize the row checker with expected column names.
        """
        super().__init__(**kwargs)
        self._sample_col = sample_col
        self._condition_col = condition_col
        self._fastq_col = fastq_col
        self._seen = set()

    def validate_and_transform(self, row):
        """
        Perform validation and transformation on a given row.
        Returns transformed row dictionary or None if row should be skipped.
        """
        self._validate_sample(row)
        self._validate_condition(row)
        self._validate_fastq(row)
        self._seen.add(row[self._sample_col])

        return {
            "sample": row[self._sample_col],
            "condition": row[self._condition_col],
            "fastq": row[self._fastq_col],
        }

    def _validate_sample(self, row):
        """Assert that the sample name exists and is unique."""
        if len(row[self._sample_col]) <= 0:
            raise AssertionError("Sample name is required.")
        if row[self._sample_col] in self._seen:
            raise AssertionError(f"Sample name {row[self._sample_col]} is duplicated.")

    def _validate_condition(self, row):
        """Assert that the condition is valid."""
        condition = row[self._condition_col].lower()
        if condition not in self.VALID_CONDITIONS:
            raise AssertionError(
                f"Condition must be one of {self.VALID_CONDITIONS}, got '{condition}'."
            )
        row[self._condition_col] = condition

    def _validate_fastq(self, row):
        """Assert that the FASTQ file exists and has valid extension."""
        fastq_path = Path(row[self._fastq_col])

        # Check if file has valid extension
        if not any(str(fastq_path).endswith(fmt) for fmt in self.VALID_FORMATS):
            raise AssertionError(
                f"FASTQ file must have one of these extensions: {self.VALID_FORMATS}. "
                f"Got: {fastq_path}"
            )


def read_head(handle, num_lines=10):
    """Read the specified number of lines from the current position."""
    lines = []
    for idx, line in enumerate(handle):
        if idx == num_lines:
            break
        lines.append(line)
    return "".join(lines)


def sniff_format(handle):
    """
    Detect the tabular format (CSV or TSV).
    """
    peek = read_head(handle)
    handle.seek(0)
    sniffer = csv.Sniffer()
    dialect = sniffer.sniff(peek)
    return dialect


def check_samplesheet(file_in, file_out):
    """
    Check that the samplesheet is valid and write out validated version.
    """
    required_columns = {"sample", "condition", "fastq"}

    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with open(file_in, newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))

        # Validate the existence of required columns
        if not required_columns.issubset(reader.fieldnames):
            req_cols = ", ".join(required_columns)
            logger.critical(f"Missing required columns. Required: {req_cols}")
            logger.critical(f"Found columns: {', '.join(reader.fieldnames)}")
            sys.exit(1)

        # Validate each row
        checker = RowChecker()
        with open(file_out, "w", newline="") as out_handle:
            writer = csv.DictWriter(
                out_handle,
                fieldnames=["sample", "condition", "fastq"],
                delimiter=",",
            )
            writer.writeheader()

            for i, row in enumerate(reader):
                try:
                    validated_row = checker.validate_and_transform(row)
                    writer.writerow(validated_row)
                except AssertionError as e:
                    logger.critical(f"Line {i + 2}: {e}")
                    sys.exit(1)


def parse_args(argv=None):
    """Define and parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate and reformat a samplesheet.",
        epilog="Example: python check_samplesheet.py samplesheet.csv samplesheet.valid.csv",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_IN",
        type=Path,
        help="Input samplesheet file",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Output validated samplesheet file",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="Logging level",
        choices=["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"],
        default="INFO",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    if not args.file_in.is_file():
        logger.error(f"Input samplesheet file does not exist: {args.file_in}")
        sys.exit(1)

    check_samplesheet(args.file_in, args.file_out)


if __name__ == "__main__":
    sys.exit(main())
