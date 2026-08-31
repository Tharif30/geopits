DECLARE @BackupSeconds INT,
        @UploadSeconds INT,
        @TotalSeconds INT;

SET @BackupSeconds =
      CAST(LEFT(@BackupStepDuration,2) AS INT) * 3600
    + CAST(SUBSTRING(@BackupStepDuration,4,2) AS INT) * 60
    + CAST(RIGHT(@BackupStepDuration,2) AS INT);

SET @UploadSeconds =
      CAST(LEFT(@UploadStepDuration,2) AS INT) * 3600
    + CAST(SUBSTRING(@UploadStepDuration,4,2) AS INT) * 60
    + CAST(RIGHT(@UploadStepDuration,2) AS INT);

SET @TotalSeconds = @BackupSeconds + @UploadSeconds;

SET @TotalJobDuration =
      RIGHT('00' + CAST(@TotalSeconds / 3600 AS VARCHAR(10)),2)
    + ':'
    + RIGHT('00' + CAST((@TotalSeconds % 3600) / 60 AS VARCHAR(2)),2)
    + ':'
    + RIGHT('00' + CAST(@TotalSeconds % 60 AS VARCHAR(2)),2);