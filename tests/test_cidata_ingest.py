import unittest
import os
import tempfile
import sys

# Ensure we can import cidata_ingest
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import cidata_ingest

class TestCidataIngest(unittest.TestCase):

    def test_ingest_cleartext_yaml_invalid_yaml(self):
        # Create a temporary file with invalid YAML
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as temp_file:
            # YAML parser will fail on this invalid construct
            temp_file.write("invalid_yaml: [\n  - missing_quote\n  : unexpected_colon")
            temp_file_path = temp_file.name

        try:
            # Call the function, expecting it to return False
            result = cidata_ingest.ingest_cleartext_yaml(temp_file_path)
            self.assertFalse(result)
        finally:
            # Cleanup
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)

    def test_ingest_cleartext_yaml_missing_file(self):
        # Call the function with a non-existent file path
        result = cidata_ingest.ingest_cleartext_yaml("/non/existent/path/that/does/not/exist.yaml")
        self.assertFalse(result)

if __name__ == '__main__':
    unittest.main()
