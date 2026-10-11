# Apple Competitor Intake Folder

Store native output files produced on Apple Intelligence devices in this directory:
`comparisons/apple/<id>.jpg` (where `<id>` matches the row ID from `testset/manifest.csv`, e.g., `1.jpg` or `01.jpg`).

## How to Produce Apple Comparison Outputs

1. Open the original test photo from `testset/photos/` on an iPhone 15 Pro, iPhone 16 series, or Apple Intelligence iPad/Mac in the **Photos** app.
2. Tap **Edit** → select **Clean Up**.
3. Tap or circle the background people to remove them, ensuring the main subject remains untouched.
4. Tap **Done** to save the edit.
5. AirDrop or export as **Unmodified Original / Full Resolution** JPEG.
6. Save the resulting file into this folder named `<id>.jpg`.

*Note (Per Requirements §3.3):* If no Apple Intelligence device is available, run the Google arm only and label the result one-armed — never fake the second arm.
