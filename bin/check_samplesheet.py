#!/usr/bin/env python3

"""
Validate and parse samplesheet for RNA modification coverage benchmarking pipeline.

Expected samplesheet format (CSV):
Required columns: sample, condition, fastq
Optional columns: genome_size, min_length, length_weight, mean_q_weight, window_q_weight,
                  keep_percent, min_mean_q, min_window_q, window_size, trim, split,
                  assembly, illumina_1, illumina_2

Example:
sample,condition,fastq,genome_size,min_length,length_weight
native_1,native,/path/to/native_1.fastq.gz,4.5m,500,10
native_2,native,/path/to/native_2.fastq.gz,4.5Mbp,,15
ivt_1,ivt,/path/to/ivt_1.fastq.gz,4500000,1000,
"""

import argparse
import csv
import logging
import sys
from pathlib import Path
import re

logger = logging.getLogger()


def parse_genome_size(size_str):
    """
    Parse genome size from various formats to bases.

    Supports: 4500000, 4.5m, 4.5M, 4.5mb, 4.5Mb, 4.5MB, 4.5Mbp, 4500k, 4500K, etc.
    Returns: integer bases or None if empty
    """
    if not size_str or size_str.strip() == '':
        return None

    size_str = size_str.strip()

    # Pattern to match number with optional unit
    pattern = r'^([0-9]+\.?[0-9]*)([kKmMgG](?:[bB][pP]?)?)?$'
    match = re.match(pattern, size_str)

    if not match:
        raise ValueError(f"Invalid genome size format: {size_str}. Expected formats: 4500000, 4.5m, 4.5Mbp, 4500k, etc.")

    value = float(match.group(1))
    unit = match.group(2)

    # Convert to bases
    if unit is None:
        # No unit, assume bases
        return int(value)

    unit_lower = unit.lower().replace('bp', '').replace('b', '')

    multipliers = {
        'k': 1_000,
        'm': 1_000_000,
        'g': 1_000_000_000
    }

    if unit_lower in multipliers:
        return int(value * multipliers[unit_lower])
    else:
        raise ValueError(f"Unknown unit in genome size: {unit}")


def parse_boolean(value):
    """Parse boolean values from strings."""
    if not value or value.strip() == '':
        return None

    value_lower = value.strip().lower()
    if value_lower in ['true', 'yes', '1', 't', 'y']:
        return True
    elif value_lower in ['false', 'no', '0', 'f', 'n']:
        return False
    else:
        raise ValueError(f"Invalid boolean value: {value}. Use: true/false, yes/no, 1/0")


class RowChecker:
    """
    Define a service that can validate and transform each given row.
    """

    VALID_CONDITIONS = ["native", "ivt"]
    VALID_FORMATS = [".fastq", ".fq", ".fastq.gz", ".fq.gz"]

    REQUIRED_COLS = ["sample", "condition", "fastq"]
    OPTIONAL_COLS = [
        "genome_size", "min_length", "length_weight", "mean_q_weight",
        "window_q_weight", "keep_percent", "min_mean_q", "min_window_q",
        "window_size", "trim", "split", "assembly", "illumina_1", "illumina_2"
    ]

    def __init__(self, **kwargs):
        """
        Initialize the row checker with expected column names.
        """
        super().__init__(**kwargs)
        self._seen = set()

    def validate_and_transform(self, row):
        """
        Perform validation and transformation on a given row.
        Returns transformed row dictionary.
        """
        self._validate_sample(row)
        self._validate_condition(row)
        self._validate_fastq(row)

        # Build result with required fields
        result = {
            "sample": row["sample"],
            "condition": row["condition"],
            "fastq": row["fastq"],
        }

        # Process optional fields
        result.update(self._process_optional_fields(row))

        self._seen.add(row["sample"])
        return result

    def _validate_sample(self, row):
        """Assert that the sample name exists and is unique."""
        if len(row["sample"]) <= 0:
            raise AssertionError("Sample name is required.")
        if row["sample"] in self._seen:
            raise AssertionError(f"Sample name {row['sample']} is duplicated.")

    def _validate_condition(self, row):
        """Assert that the condition is valid."""
        condition = row["condition"].lower()
        if condition not in self.VALID_CONDITIONS:
            raise AssertionError(
                f"Condition must be one of {self.VALID_CONDITIONS}, got '{condition}'."
            )
        row["condition"] = condition

    def _validate_fastq(self, row):
        """Assert that the FASTQ file has valid extension."""
        fastq_path = Path(row["fastq"])

        # Check if file has valid extension
        if not any(str(fastq_path).endswith(fmt) for fmt in self.VALID_FORMATS):
            raise AssertionError(
                f"FASTQ file must have one of these extensions: {self.VALID_FORMATS}. "
                f"Got: {fastq_path}"
            )

    def _process_optional_fields(self, row):
        """Process and validate optional fields."""
        result = {}

        # Genome size - parse to bases
        if "genome_size" in row and row["genome_size"].strip():
            try:
                result["genome_size"] = parse_genome_size(row["genome_size"])
            except ValueError as e:
                raise AssertionError(f"Genome size error: {e}")

        # Numeric fields
        numeric_fields = [
            "min_length", "length_weight", "mean_q_weight", "window_q_weight",
            "keep_percent", "min_mean_q", "min_window_q", "window_size", "split"
        ]

        for field in numeric_fields:
            if field in row and row[field].strip():
                try:
                    # Use float for weights/percentages, int for lengths
                    if field in ["length_weight", "mean_q_weight", "window_q_weight",
                                 "keep_percent", "min_mean_q", "min_window_q"]:
                        result[field] = float(row[field])
                    else:
                        result[field] = int(row[field])
                except ValueError:
                    raise AssertionError(f"Invalid numeric value for {field}: {row[field]}")

        # Boolean field - trim
        if "trim" in row and row["trim"].strip():
            try:
                result["trim"] = parse_boolean(row["trim"])
            except ValueError as e:
                raise AssertionError(f"Trim field error: {e}")

        # File path fields
        file_fields = ["assembly", "illumina_1", "illumina_2"]
        for field in file_fields:
            if field in row and row[field].strip():
                result[field] = row[field].strip()

        return result


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

        # Get all column names from input
        all_columns = list(reader.fieldnames)

        # Validate each row
        checker = RowChecker()
        with open(file_out, "w", newline="") as out_handle:
            writer = csv.DictWriter(
                out_handle,
                fieldnames=all_columns,
                delimiter=",",
            )
            writer.writeheader()

            for i, row in enumerate(reader):
                try:
                    validated_row = checker.validate_and_transform(row)

                    # Write row with all original columns, using empty string for missing optional fields
                    output_row = {col: "" for col in all_columns}
                    output_row.update(validated_row)

                    # Convert back genome_size to string if present
                    if "genome_size" in output_row and output_row["genome_size"]:
                        output_row["genome_size"] = str(output_row["genome_size"])

                    # Convert boolean to string if present
                    if "trim" in output_row and output_row["trim"] is not None:
                        output_row["trim"] = "true" if output_row["trim"] else "false"

                    # Convert numeric fields to strings
                    for col in all_columns:
                        if col in output_row and output_row[col] is not None and col not in ["sample", "condition", "fastq", "assembly", "illumina_1", "illumina_2"]:
                            if isinstance(output_row[col], (int, float)):
                                output_row[col] = str(output_row[col])

                    writer.writerow(output_row)
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
