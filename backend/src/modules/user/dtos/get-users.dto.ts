import { Transform } from "class-transformer";
import { IsInt, IsNotEmpty, Min, IsOptional } from "class-validator";

export class GetUsersReqDto {
  @IsOptional()
  @IsInt()
  id: number;

  @Transform(({ value }) => Number(value))
  @IsNotEmpty()
  @IsInt()
  @Min(1)
  page: number;

  @Transform(({ value }) => Number(value))
  @IsNotEmpty()
  @IsInt()
  @Min(0)
  limit: number;
}
