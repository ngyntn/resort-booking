import {
  IsDateString,
  IsNumberString,
  IsOptional,
  IsPhoneNumber,
  IsString,
  Length,
} from 'class-validator';
import { OneOf } from 'common/decorators/validation.decorator';

export class UpdateUserInfoReqDto {
  @IsOptional()
  @IsNumberString()
  @Length(12, 12)
  cccd: string;

  @IsOptional()
  @IsString()
  identityIssuedAt: string;

  @IsOptional()
  @IsString()
  identityIssuedPlace: string;

  @IsOptional()
  @IsString()
  permanentAddress: string;

  @IsOptional()
  @IsPhoneNumber()
  phone: string;

  @IsOptional()
  @IsString()
  name: string;

  @IsOptional()
  @IsDateString()
  dob: string;

  @IsOptional()
  @IsString()
  @OneOf(['male', 'female', 'other'])
  gender: 'male' | 'female' | 'other';

  @IsOptional()
  @IsString()
  note: string;
}
